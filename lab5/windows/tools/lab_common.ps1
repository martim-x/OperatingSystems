# ============================================================================
# lab_common.ps1 - общие функции харнесса ЛР5 (Windows, PowerShell 5.1)
# Подключается через dot-source: . (Join-Path $PSScriptRoot 'lab_common.ps1')
#
# ВАЖНО: файл сохранён в UTF-8 WITH BOM. PowerShell 5.1 без BOM читает
# кириллицу как ANSI (cp1251/cp866) и ломает строки. Не пересохраняйте в ANSI.
# ============================================================================

$script:LabLogPath = $null

# --- C#-обвязка над user32/kernel32 -----------------------------------------
# Только ASCII внутри исходника: CodeDom-компилятор не любит не-ASCII в коде.

$script:LabWin32Source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class LabWin32
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int width, int height, bool repaint);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    public class WindowInfo
    {
        public IntPtr Handle;
        public uint ProcessId;
        public string Title;
    }

    public static List<WindowInfo> VisibleWindows()
    {
        List<WindowInfo> found = new List<WindowInfo>();
        EnumWindowsProc callback = delegate(IntPtr hWnd, IntPtr lParam)
        {
            if (!IsWindowVisible(hWnd)) return true;
            int length = GetWindowTextLength(hWnd);
            if (length <= 0) return true;
            StringBuilder title = new StringBuilder(length + 2);
            GetWindowText(hWnd, title, title.Capacity);
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            WindowInfo info = new WindowInfo();
            info.Handle = hWnd;
            info.ProcessId = pid;
            info.Title = title.ToString();
            found.Add(info);
            return true;
        };
        EnumWindows(callback, IntPtr.Zero);
        return found;
    }
}
'@

# --- инициализация ----------------------------------------------------------

function Initialize-LabNative {
    if (-not ('LabWin32' -as [type])) {
        Add-Type -TypeDefinition $script:LabWin32Source -ErrorAction Stop
    }
    try { Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue } catch { }
    try { Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue } catch { }
}

function Initialize-LabDpi {
    Initialize-LabNative
    try { [void][LabWin32]::SetProcessDPIAware() } catch { }
}

function Initialize-LabConsole {
    # Вывод дочерних процессов идёт в cp65001, декодируем его как UTF-8.
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
    try { $null = & chcp.com 65001 2>&1 } catch { }
}

# --- логирование ------------------------------------------------------------

function Start-LabLog {
    param([string]$Path)
    $script:LabLogPath = $Path
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    try { [System.IO.File]::WriteAllText($Path, '', (New-Object System.Text.UTF8Encoding($false))) } catch { }
}

function Write-LabText {
    param([string]$Text)
    [Console]::Out.Write($Text)
    [Console]::Out.Flush()
    if ($script:LabLogPath) {
        try { [System.IO.File]::AppendAllText($script:LabLogPath, $Text, (New-Object System.Text.UTF8Encoding($false))) } catch { }
    }
}

function Write-LabLine {
    param([string]$Text = '')
    Write-LabText ($Text + "`r`n")
}

# --- пути и маски -----------------------------------------------------------

function Resolve-LabRoot {
    param([string]$Requested = '', [string]$Fallback = '')

    $candidates = New-Object System.Collections.ArrayList
    if ($Requested) {
        [void]$candidates.Add($Requested)
        [void]$candidates.Add((Join-Path $Requested 'lab5\windows\tools'))
    } else {
        if (Test-Path -LiteralPath 'C:\OS5') {
            [void]$candidates.Add('C:\OS5')
            [void]$candidates.Add('C:\OS5\lab5\windows\tools')
        }
    }
    if ($Fallback) { [void]$candidates.Add($Fallback) }

    foreach ($c in $candidates) {
        if (-not $c) { continue }
        if (-not (Test-Path -LiteralPath $c)) { continue }
        if (Test-Path -LiteralPath (Join-Path $c 'queue')) { return (Resolve-Path -LiteralPath $c).Path }
    }
    if ($Requested) {
        throw ('В каталоге "' + $Requested + '" нет подкаталога queue. Проверьте -Root.')
    }
    if ($Fallback) { return $Fallback }
    return (Get-Location).Path
}

function Get-LabQueueNumber {
    param([string]$Name)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    if ($base -match '^([0-9]+)') { return $Matches[1] }
    return $base
}

function Get-LabProcessorCount {
    $n = 0
    if ([int]::TryParse([string]$env:NUMBER_OF_PROCESSORS, [ref]$n)) {
        if ($n -gt 0) { return $n }
    }
    return [Environment]::ProcessorCount
}

function Format-LabMask {
    param([int64]$Mask, [int]$Width = 0)
    if ($Width -le 0) { $Width = Get-LabProcessorCount }
    if ($Width -le 0) { $Width = 64 }
    if ($Width -gt 64) { $Width = 64 }
    $text = [Convert]::ToString($Mask, 2)
    if ($text.Length -gt $Width) { $text = $text.Substring($text.Length - $Width) }
    return $text.PadLeft($Width, '0')
}

function ConvertTo-LabMask {
    param([string]$Value)
    $v = ([string]$Value).Trim().ToLower()
    $ncpu = Get-LabProcessorCount
    if ($v -eq 'all' -or $v -eq '') {
        if ($ncpu -ge 63) { return [int64]-1 }
        return [int64]([math]::Pow(2, $ncpu) - 1)
    }
    if ($v -like '0x*') { return [Convert]::ToInt64($v.Substring(2), 16) }
    if ($v -like '0b*') { return [Convert]::ToInt64($v.Substring(2), 2) }
    return [int64]$v
}

# --- экран и окна -----------------------------------------------------------

function Get-LabWorkingArea {
    Initialize-LabNative
    $a = [System.Windows.Forms.SystemInformation]::WorkingArea
    return [pscustomobject]@{ Left = $a.Left; Top = $a.Top; Width = $a.Width; Height = $a.Height }
}

function Save-LabScreenshot {
    param([string]$Path, [int]$DelayMs = 200)

    Initialize-LabDpi
    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }

    $area = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object System.Drawing.Bitmap([int]$area.Width, [int]$area.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $size = New-Object System.Drawing.Size([int]$bitmap.Width, [int]$bitmap.Height)
        $graphics.CopyFromScreen([int]$area.Left, [int]$area.Top, 0, 0, $size)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    return $Path
}

function Get-LabProcessWindows {
    param([int[]]$ProcessId = @(), [string]$TitleHint = '')

    Initialize-LabNative
    $ids = New-Object System.Collections.ArrayList
    foreach ($procId in $ProcessId) {
        if ($procId -le 0) { continue }
        [void]$ids.Add([uint32]$procId)
        # Окно консольного процесса принадлежит conhost.exe (или OpenConsole.exe),
        # поэтому добавляем консольных детей этого процесса.
        try {
            $kids = @(Get-CimInstance -ClassName Win32_Process -Filter ('ParentProcessId=' + $procId) -ErrorAction Stop)
        } catch {
            $kids = @()
        }
        foreach ($k in $kids) {
            if ($k.Name -match '^(conhost|OpenConsole|WindowsTerminal)\.exe$') {
                [void]$ids.Add([uint32]$k.ProcessId)
            }
        }
    }

    $result = @()
    foreach ($w in [LabWin32]::VisibleWindows()) {
        $match = $false
        if ($ids -contains $w.ProcessId) { $match = $true }
        if (-not $match -and $TitleHint) {
            if ($w.Title -like ('*' + $TitleHint + '*')) { $match = $true }
        }
        if ($match) {
            $result += [pscustomobject]@{
                Handle    = $w.Handle
                ProcessId = [int]$w.ProcessId
                Title     = $w.Title
            }
        }
    }
    return $result
}

function Set-LabWindowRect {
    param([IntPtr]$Handle, [int]$X, [int]$Y, [int]$Width, [int]$Height, [switch]$Foreground)

    if ($Handle -eq [IntPtr]::Zero) { return $false }
    [void][LabWin32]::ShowWindow($Handle, 9)
    Start-Sleep -Milliseconds 120
    [void][LabWin32]::MoveWindow($Handle, $X, $Y, $Width, $Height, $true)
    if ($Foreground) { [void][LabWin32]::SetForegroundWindow($Handle) }
    Start-Sleep -Milliseconds 120
    return $true
}

function Wait-LabWindow {
    param([int]$ProcessId, [int]$TimeoutMs = 10000, [string]$TitleHint = '', [int64[]]$Exclude = @())

    $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
    while ((Get-Date) -lt $deadline) {
        $cand = @(Get-LabProcessWindows -ProcessId @($ProcessId))
        $cand = @($cand | Where-Object { -not ($Exclude -contains $_.Handle.ToInt64()) })
        if ($cand.Count -gt 0) { return $cand[0] }
        Start-Sleep -Milliseconds 250
    }
    if ($TitleHint) {
        $cand = @(Get-LabProcessWindows -ProcessId @() -TitleHint $TitleHint)
        $cand = @($cand | Where-Object { -not ($Exclude -contains $_.Handle.ToInt64()) })
        if ($cand.Count -gt 0) { return $cand[0] }
    }
    return $null
}

# --- очистка результатов -----------------------------------------------------
# Вынесено из start_driver.ps1, чтобы поведение можно было проверить offline
# (test_harness.ps1) и чтобы решение «чистить / не чистить» осталось в одном месте.

function Clear-LabResults {
    param([string]$Work, [switch]$IncludeQueue)

    $cleared = @()
    if (-not $Work) { return $cleared }
    foreach ($sub in @('done', 'shots', 'logs')) {
        $dir = Join-Path $Work $sub
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        }
        $cleared += $dir
    }
    if ($IncludeQueue) {
        $queueDir = Join-Path $Work 'queue'
        if (Test-Path -LiteralPath $queueDir) {
            Get-ChildItem -LiteralPath $queueDir -Filter '*.cmd' -ErrorAction SilentlyContinue | ForEach-Object {
                try { Remove-Item -LiteralPath $_.FullName -Force } catch { }
            }
            $cleared += $queueDir
        }
    }
    return $cleared
}

# --- процессы и потоки ------------------------------------------------------

function Test-LabProcessAlive {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return $false }
    $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($p) { return $true }
    return $false
}

function Stop-LabTree {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return }
    try { $null = & taskkill.exe /PID $ProcessId /T /F 2>&1 } catch { }
    Start-Sleep -Milliseconds 400
}

function Get-LabChildren {
    param([int]$ParentId, [string]$NamePattern = '')

    $list = @()
    try {
        $list = @(Get-CimInstance -ClassName Win32_Process -Filter ('ParentProcessId=' + $ParentId) -ErrorAction Stop)
    } catch {
        $list = @()
    }
    $list = @($list | Where-Object { $_.Name -notmatch '^(conhost|OpenConsole|WindowsTerminal|WerFault)\.exe$' })
    if ($NamePattern) {
        $filtered = @($list | Where-Object { $_.Name -like $NamePattern })
        if ($filtered.Count -gt 0) { return $filtered }
    }
    return $list
}

function Get-LabProcessRow {
    param([int]$ProcessId)

    $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $p) { return $null }

    $ppid = 0
    try {
        $c = Get-CimInstance -ClassName Win32_Process -Filter ('ProcessId=' + $ProcessId) -ErrorAction Stop
        $ppid = [int]$c.ParentProcessId
    } catch { }

    $affinity = [int64]0
    try { $affinity = $p.ProcessorAffinity.ToInt64() } catch { }

    $class = ''
    try { $class = [string]$p.PriorityClass } catch { }

    $base = 0
    try { $base = $p.BasePriority } catch { }

    return [pscustomobject]@{
        Id      = $ProcessId
        PPID    = $ppid
        Name    = $p.ProcessName
        Class   = $class
        Threads = $p.Threads.Count
        Base    = $base
        Mask    = (Format-LabMask -Mask $affinity)
    }
}

function Show-LabProcessTable {
    param([int[]]$ProcessId)

    Write-LabLine ''
    Write-LabLine '--- состояние процессов (эквивалент ps) ---'
    Write-LabLine ('{0,-7} {1,-7} {2,-16} {3,-12} {4,-8} {5,-6} {6}' -f 'PID', 'PPID', 'Имя', 'Класс', 'Потоков', 'База', 'Маска родственности (двоично)')
    foreach ($procId in $ProcessId) {
        $row = Get-LabProcessRow -ProcessId $procId
        if (-not $row) {
            Write-LabLine ('{0,-7} {1}' -f $procId, '(процесс уже завершён)')
            continue
        }
        Write-LabLine ('{0,-7} {1,-7} {2,-16} {3,-12} {4,-8} {5,-6} {6}' -f $row.Id, $row.PPID, $row.Name, $row.Class, $row.Threads, $row.Base, $row.Mask)
    }
    Write-LabLine ('число логических процессоров: ' + (Get-LabProcessorCount))
}

function Show-LabThreadTable {
    param([int]$ProcessId, [string]$Title = '')

    $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $p) {
        Write-LabLine ('[!] процесс ' + $ProcessId + ' не найден')
        return
    }
    Write-LabLine ''
    Write-LabLine ('--- потоки процесса ' + $ProcessId + ' ' + $Title + ' ---')
    Write-LabLine ('{0,-8} {1,-16} {2,-6} {3}' -f 'TID', 'Уровень', 'База', 'Состояние')
    foreach ($t in $p.Threads) {
        $level = ''
        try { $level = [string]$t.PriorityLevel } catch { }
        $state = ''
        try { $state = [string]$t.ThreadState } catch { }
        Write-LabLine ('{0,-8} {1,-16} {2,-6} {3}' -f $t.Id, $level, $t.BasePriority, $state)
    }
}

function Get-LabThreadIds {
    param([int]$ProcessId)

    $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $p) { return @() }
    return @($p.Threads | ForEach-Object { [int]$_.Id })
}
