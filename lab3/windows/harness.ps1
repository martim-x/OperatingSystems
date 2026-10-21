<#>
.SYNOPSIS
    Windows Harness for Lab 3 - запускает программы и делает чистые скриншоты без UI
.DESCRIPTION
    Запускает консольные приложения в максимизированных окнах, ждёт нажатия клавиши,
    делает скриншот только клиентской области консоли через Graphics.CopyFromScreen.
    Не показывает никаких UI, работает скрыто.
#>

param(
    [string]$ExePath,
    [string]$Args = "",
    [string]$OutDir = "скрины",
    [string]$FileName = "screenshot.png",
    [int]$WaitKey = 1  # 1 = ждать нажатия клавиши, 0 = не ждать
)

Add-Type @"
using System;
using System.Drawing;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class ScreenCapture {
    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    
    [DllImport("user32.dll")]
    private static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    
    [DllImport("user32.dll")]
    private static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);
    
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X, Y; }
    
    public static Bitmap CaptureConsoleWindow(IntPtr hWnd) {
        RECT rect;
        GetClientRect(hWnd, out rect);
        POINT pt = new POINT { X = rect.Left, Y = rect.Top };
        ClientToScreen(hWnd, ref pt);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        Bitmap bmp = new Bitmap(width, height);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.CopyFromScreen(pt.X, pt.Y, 0, 0, new Size(width, height));
        }
        return bmp;
    }
    
    public static void MaximizeWindow(IntPtr hWnd) {
        ShowWindow(hWnd, 3); // SW_MAXIMIZE = 3
    }
}
"@

# Создаём папку для скриншотов
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$fullPath = Join-Path (Get-Location) $ExePath
if (-not (Test-Path $fullPath)) {
    Write-Error "Файл не найден: $fullPath"
    exit 1
}

# Запускаем процесс в новом окне
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $fullPath
$psi.Arguments = $Args
$psi.UseShellExecute = $true
$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Maximized

$proc = [System.Diagnostics.Process]::Start($psi)
if ($null -eq $proc) {
    Write-Error "Не удалось запустить: $fullPath $Args"
    exit 1
}

# Ждём, пока окно создастся и станет foreground
Start-Sleep -Milliseconds 500
$hWnd = $proc.MainWindowHandle
if ($hWnd -eq 0) {
    # Пробуем найти через GetForegroundWindow
    $hWnd = [ScreenCapture]::GetForegroundWindow()
}

# Максимизируем окно
[ScreenCapture]::MaximizeWindow($hWnd)
Start-Sleep -Milliseconds 300

if ($WaitKey -eq 1) {
    Write-Host "Программа запущена (PID=$($proc.Id)). Нажмите любую клавишу для скриншота..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Делаем скриншот клиентской области
try {
    $bmp = [ScreenCapture]::CaptureConsoleWindow($hWnd)
    $outFile = Join-Path $OutDir $FileName
    $bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Скриншот сохранён: $outFile"
} catch {
    Write-Error "Ошибка скриншота: $_"
}

# Ждём завершения процесса (если он не завершился сам)
if (-not $proc.HasExited) {
    $proc.WaitForExit(5000)
    if (-not $proc.HasExited) {
        $proc.Kill()
    }
}