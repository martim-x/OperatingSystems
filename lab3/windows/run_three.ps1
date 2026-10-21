<#>
.SYNOPSIS
    Запускает 3 процесса одновременно для демонстрации параллельной работы
.DESCRIPTION
    Запускает Lab-03a (который создаёт 2 дочерних) + сам Lab-03a = 3 процесса вместе,
    или запускает 3 копии Lab-03x одновременно. Делает скриншот всех трёх.
#>

param(
    [string]$Mode = "lab03a",  # "lab03a" или "3x"
    [string]$OutDir = "скрины/уровень_4-5",
    [string]$FileName = "task11_three_proc.png"
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
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X, Y; }
    
    public static Bitmap CaptureConsoleWindow(IntPtr hWnd) {
        RECT rect; GetClientRect(hWnd, out rect);
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
    public static void MaximizeWindow(IntPtr hWnd) { ShowWindow(hWnd, 3); }
    
    public static IntPtr[] GetTopLevelWindows(uint pid) {
        var handles = new System.Collections.Generic.List<IntPtr>();
        EnumWindows((hWnd, lParam) => {
            uint wpid; GetWindowThreadProcessId(hWnd, out wpid);
            if (wpid == pid) {
                // Только top-level окна (без родителя)
                if (GetParent(hWnd) == IntPtr.Zero) handles.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);
        return handles.ToArray();
    }
    
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] private static extern IntPtr GetParent(IntPtr hWnd);
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
}
"@

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$processes = @()
$handles = @()

if ($Mode -eq "lab03a") {
    # Запускаем Lab-03a.exe который сам создаст 2 дочерних
    $exe = ".\build\Lab-03a.exe"
    if (-not (Test-Path $exe)) { $exe = ".\Lab-03a.exe" }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = "3"
    $psi.UseShellExecute = $true
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Maximized
    $proc = [System.Diagnostics.Process]::Start($psi)
    $processes += $proc
    Write-Host "Запущен Lab-03a (PID=$($proc.Id))"
} else {
    # Запускаем 3 копии Lab-03x.exe
    $exe = ".\build\Lab-03x.exe"
    if (-not (Test-Path $exe)) { $exe = ".\Lab-03x.exe" }
    for ($i=1; $i -le 3; $i++) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = "10"
        $psi.UseShellExecute = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Maximized
        $proc = [System.Diagnostics.Process]::Start($psi)
        $processes += $proc
        Write-Host "Запущен Lab-03x #$i (PID=$($proc.Id))"
    }
}

# Ждём создания окон
Start-Sleep -Milliseconds 800

# Максимизируем все окна
foreach ($proc in $processes) {
    if ($proc.MainWindowHandle -ne 0) {
        [ScreenCapture]::MaximizeWindow($proc.MainWindowHandle)
        $handles += $proc.MainWindowHandle
    }
}

# Также ищем дочерние окна для Lab-03a
if ($Mode -eq "lab03a" -and $processes.Count -gt 0) {
    $pid = $processes[0].Id
    $childHandles = [ScreenCapture]::GetTopLevelWindows($pid)
    foreach ($h in $childHandles) {
        if ($handles -notcontains $h) { $handles += $h }
    }
}

Write-Host "Найдено окон: $($handles.Count). Нажмите любую клавишу для скриншота..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Делаем скриншот экрана целиком (все окна)
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$g.Dispose()

$outFile = Join-Path (Get-Location) $OutDir $FileName
$bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Скриншот сохранён: $outFile"

# Завершаем процессы
foreach ($proc in $processes) {
    if (-not $proc.HasExited) {
        $proc.WaitForExit(3000)
        if (-not $proc.HasExited) { $proc.Kill() }
    }
}