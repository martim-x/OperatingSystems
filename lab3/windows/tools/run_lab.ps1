# run_lab.ps1 - driver for LR3 on Windows (clean frames)
# Runs in an INTERACTIVE session (schtasks /IT); an SSH shell lives in
# session 0 and cannot see the desktop.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32 {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] public static extern bool SetConsoleScreenBufferSize(IntPtr h, COORD size);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool SetCurrentConsoleFontEx(IntPtr h, bool max, ref CONSOLE_FONT_INFO_EX f);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct COORD { public short X, Y; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct CONSOLE_FONT_INFO_EX {
        public uint cbSize; public uint nFont; public COORD dwFontSize;
        public int FontFamily; public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string FaceName;
    }
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder sb, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    // locate the real console window (conhost or Windows Terminal host)
    public static IntPtr ConsoleHwnd = IntPtr.Zero;
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder sb, int n);
    public static IntPtr FindWindowByTitle(string part) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            if (!IsWindowVisible(h)) return true;
            System.Text.StringBuilder sb = new System.Text.StringBuilder(512);
            GetWindowText(h, sb, 512);
            string t = sb.ToString();
            if (t.Length > 0 && t.IndexOf(part, StringComparison.OrdinalIgnoreCase) >= 0) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static int[] RectOf(IntPtr h) {
        RECT r;
        if (!GetWindowRect(h, out r)) return new int[] { -1, -1, 0, 0 };
        return new int[] { r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top };
    }
    public static int[] ForegroundRect() {
        IntPtr h = GetForegroundWindow();
        RECT r;
        if (!GetWindowRect(h, out r)) return new int[] { -1, -1, 0, 0 };
        return new int[] { r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top };
    }
    public static int[] FindConsoleRect() {
        int[] found = new int[] { -1, -1, 0, 0 };
        ConsoleHwnd = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr p) {
            if (!IsWindowVisible(h)) return true;
            System.Text.StringBuilder sb = new System.Text.StringBuilder(256);
            GetClassName(h, sb, 256);
            string cls = sb.ToString();
            if (cls == "ConsoleWindowClass" || cls == "CASCADIA_HOSTING_WINDOW_CLASS") {
                RECT r;
                if (GetWindowRect(h, out r)) {
                    int w = r.Right - r.Left, ht = r.Bottom - r.Top;
                    if (w > 300 && ht > 200 && w * ht > found[2] * found[3]) {
                        found[0] = r.Left; found[1] = r.Top; found[2] = w; found[3] = ht;
                        ConsoleHwnd = h;
                    }
                }
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    // returns int[] {x, y, w, h} of the console area (no System.Drawing types:
    // Add-Type does not reference that assembly by default)
    public static int[] ContentRect(int width, int height, byte[] rgb) {
        System.Collections.Generic.Dictionary<int,int> hist = new System.Collections.Generic.Dictionary<int,int>();
        for (int y = 0; y < height; y += 3)
            for (int x = 0; x < width; x += 3) {
                int i = (y * width + x) * 3;
                int c = (rgb[i] << 16) | (rgb[i+1] << 8) | rgb[i+2];
                int n; hist.TryGetValue(c, out n); hist[c] = n + 1;
            }
        int modal = 0, best = -1;
        foreach (var kv in hist) if (kv.Value > best) { best = kv.Value; modal = kv.Key; }
        int mr = (modal >> 16) & 0xFF, mg = (modal >> 8) & 0xFF, mb = modal & 0xFF;
        int minx = width, miny = height, maxx = 0, maxy = 0, hits = 0;
        int tol = 8;
        for (int y = 0; y < height; y++)
            for (int x = 0; x < width; x++) {
                int i = (y * width + x) * 3;
                if (Math.Abs(rgb[i] - mr) <= tol && Math.Abs(rgb[i+1] - mg) <= tol && Math.Abs(rgb[i+2] - mb) <= tol) {
                    hits++;
                    if (x < minx) minx = x; if (x > maxx) maxx = x;
                    if (y < miny) miny = y; if (y > maxy) maxy = y;
                }
            }
        if (hits < 1000 || maxx <= minx || maxy <= miny) return new int[] { 0, 0, width, height };
        int pad = 12;
        minx = Math.Max(0, minx - pad); miny = Math.Max(0, miny - pad);
        maxx = Math.Min(width - 1, maxx + pad); maxy = Math.Min(height - 1, maxy + pad);
        return new int[] { minx, miny, maxx - minx + 1, maxy - miny + 1 };
    }
    public static void BigFont(short px) {
        IntPtr outH = GetStdHandle(-11);
        CONSOLE_FONT_INFO_EX f = new CONSOLE_FONT_INFO_EX();
        f.cbSize = (uint)Marshal.SizeOf(f);
        f.dwFontSize = new COORD { X = 0, Y = px };
        f.FontFamily = 54; f.FontWeight = 400; f.FaceName = "Consolas";
        SetCurrentConsoleFontEx(outH, false, ref f);
        SetConsoleScreenBufferSize(outH, new COORD { X = 220, Y = 70 });
        ShowWindow(GetConsoleWindow(), 3);
    }
    public static void Focus() {
        IntPtr h = GetConsoleWindow();
        ShowWindow(h, 3);
        uint pid;
        uint fg = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        uint me = GetCurrentThreadId();
        AttachThreadInput(me, fg, true);
        SetForegroundWindow(h);
        SetWindowPos(h, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002);
        SetWindowPos(h, new IntPtr(-2), 0, 0, 0, 0, 0x0001 | 0x0002);
        AttachThreadInput(me, fg, false);
        SetForegroundWindow(h);
    }
}
"@
try { [W32]::BigFont(22) } catch { W ("FONT FAILED: " + $_.Exception.Message) }
try { [W32]::Focus() } catch { }

$SYNC  = "C:\lab3_sync"
$QUEUE = "$SYNC\queue"
$DONE  = "$SYNC\done"
$SHOTS = "$SYNC\shots"
foreach ($d in @($SYNC, $QUEUE, $DONE, $SHOTS)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$LOG = "$SYNC\driver.log"
function W([string]$m) {
    # log to file only: console text would end up inside the captured frame
    $line = "{0} {1}" -f (Get-Date -Format "HH:mm:ss"), $m
    Add-Content -Path $LOG -Value $line -Encoding UTF8
}

# Capture the console CLIENT area so the terminal fills the frame.
# -FullScreen is used for @gui commands that open their own window.
function Take-Shot([string]$path, [switch]$FullScreen, [switch]$Foreground, [string]$Title = "", [IntPtr]$Hwnd = [IntPtr]::Zero) {
    if ($Hwnd -ne [IntPtr]::Zero) {
        $fr = [W32]::RectOf($Hwnd)
        $vs2 = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $full = New-Object System.Drawing.Bitmap $vs2.Width, $vs2.Height
        $g = [System.Drawing.Graphics]::FromImage($full)
        $g.CopyFromScreen($vs2.Location, [System.Drawing.Point]::Empty, $vs2.Size)
        $g.Dispose()
        if ($fr[0] -ge 0 -and $fr[2] -gt 200 -and $fr[3] -gt 150) {
            $bmp = $full.Clone((New-Object System.Drawing.Rectangle $fr[0], $fr[1], $fr[2], $fr[3]), $full.PixelFormat)
        } else { $bmp = $full.Clone() }
        $full.Dispose()
    } elseif ($Title -ne "") {
        $hw = [W32]::FindWindowByTitle($Title)
        $fr = if ($hw -ne [IntPtr]::Zero) { [W32]::RectOf($hw) } else { @(-1,-1,0,0) }
        $vs2 = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $full = New-Object System.Drawing.Bitmap $vs2.Width, $vs2.Height
        $g = [System.Drawing.Graphics]::FromImage($full)
        $g.CopyFromScreen($vs2.Location, [System.Drawing.Point]::Empty, $vs2.Size)
        $g.Dispose()
        if ($fr[0] -ge 0 -and $fr[2] -gt 200 -and $fr[3] -gt 150) {
            $bmp = $full.Clone((New-Object System.Drawing.Rectangle $fr[0], $fr[1], $fr[2], $fr[3]), $full.PixelFormat)
        } else { $bmp = $full.Clone() }
        $full.Dispose()
    } elseif ($Foreground) {
        $fr = [W32]::ForegroundRect()
        $vs2 = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $full = New-Object System.Drawing.Bitmap $vs2.Width, $vs2.Height
        $g = [System.Drawing.Graphics]::FromImage($full)
        $g.CopyFromScreen($vs2.Location, [System.Drawing.Point]::Empty, $vs2.Size)
        $g.Dispose()
        if ($fr[0] -ge 0 -and $fr[2] -gt 200 -and $fr[3] -gt 150) {
            $bmp = $full.Clone((New-Object System.Drawing.Rectangle $fr[0], $fr[1], $fr[2], $fr[3]), $full.PixelFormat)
        } else { $bmp = $full.Clone() }
        $full.Dispose()
    } elseif ($FullScreen) {
        $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
        $g.Dispose()
    } else {
        # full grab, then crop to the console's uniform background (works for
        # both conhost and Windows Terminal, where GetConsoleWindow is useless)
        $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $full = New-Object System.Drawing.Bitmap $vs.Width, $vs.Height
        $g = [System.Drawing.Graphics]::FromImage($full)
        $g.CopyFromScreen($vs.Location, [System.Drawing.Point]::Empty, $vs.Size)
        $g.Dispose()
        $wr = [W32]::FindConsoleRect()
        if ($wr[0] -lt 0) { Start-Sleep -Milliseconds 200; $wr = [W32]::FindConsoleRect() }
        if ($wr[0] -lt 0) { W "window lookup failed, colour crop" }
        if ($wr[0] -ge 0) {
            # client area only: no title bar, no borders
            $cr = New-Object W32+RECT
            [void][W32]::GetClientRect([W32]::ConsoleHwnd, [ref]$cr)
            $cp = New-Object W32+POINT
            $cp.X = 0; $cp.Y = 0
            [void][W32]::ClientToScreen([W32]::ConsoleHwnd, [ref]$cp)
            $rect = New-Object System.Drawing.Rectangle $cp.X, $cp.Y, ($cr.Right - $cr.Left), ($cr.Bottom - $cr.Top)
        } else {
            $bd = $full.LockBits((New-Object System.Drawing.Rectangle 0,0,$full.Width,$full.Height),
                                 [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                                 [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $bytes = New-Object byte[] ($bd.Stride * $full.Height)
            [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
            $full.UnlockBits($bd)
            $rc = [W32]::ContentRect($full.Width, $full.Height, $bytes)
            $px = [Math]::Max(0, $rc[0] - 28)
            $py = [Math]::Max(0, $rc[1] - 8)
            $pw = [Math]::Min($full.Width - $px, $rc[2] + 56)
            $ph = [Math]::Min($full.Height - $py, $rc[3] + 16)
            $rect = New-Object System.Drawing.Rectangle $px, $py, $pw, $ph
        }
        $bmp = $full.Clone($rect, $full.PixelFormat)
        $full.Dispose()
        # drop the terminal tab/title strip: first row that is mostly background
        $mid = [Math]::Floor($bmp.Height / 2)
        $h2 = @{}
        for ($x = 0; $x -lt $bmp.Width; $x += 4) {
            $c = $bmp.GetPixel($x, $mid)
            $k2 = "$($c.R),$($c.G),$($c.B)"
            if ($h2.ContainsKey($k2)) { $h2[$k2]++ } else { $h2[$k2] = 1 }
        }
        $bg = ($h2.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key -split ','
        $top = 0
        for ($y = 0; $y -lt [Math]::Min(160, $bmp.Height); $y++) {
            $hit = 0; $tot = 0
            for ($x = 0; $x -lt $bmp.Width; $x += 8) {
                $tot++
                $c = $bmp.GetPixel($x, $y)
                if ([Math]::Abs($c.R - [int]$bg[0]) -le 8 -and [Math]::Abs($c.G - [int]$bg[1]) -le 8 -and [Math]::Abs($c.B - [int]$bg[2]) -le 8) { $hit++ }
            }
            if ($tot -gt 0 -and ($hit / $tot) -ge 0.7) { $top = $y; break }
        }
        if ($top -gt 4) {
            $bmp2 = $bmp.Clone((New-Object System.Drawing.Rectangle 0, $top, $bmp.Width, ($bmp.Height - $top)), $bmp.PixelFormat)
            $bmp.Dispose(); $bmp = $bmp2
        }
        if ($bmp.Width -lt 2100) {
            $k = [Math]::Min(1.8, 2100.0 / $bmp.Width)
            $big = New-Object System.Drawing.Bitmap ([int]($bmp.Width * $k)), ([int]($bmp.Height * $k))
            $gg = [System.Drawing.Graphics]::FromImage($big)
            $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $gg.DrawImage($bmp, 0, 0, $big.Width, $big.Height)
            $gg.Dispose(); $bmp.Dispose(); $bmp = $big
        }
    }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Write-Wrapped([string]$text, [string]$Color = "", [int]$Indent = 0) {
    $width = 118
    $pad = " " * $Indent
    foreach ($line in ($text -split "`r?`n")) {
        if ($line.Length -le $width) {
            if ($Color) { Write-Host $pad$line -ForegroundColor $Color }
            else { Write-Host $pad$line }
            continue
        }
        # keep paths intact: break at separators nearest to the limit
        $rest = $line
        $first = $true
        while ($rest.Length -gt $width) {
            $cut = $width
            $cands = @(($rest.LastIndexOf("\", $width)), ($rest.LastIndexOf("/", $width)),
                       $rest.LastIndexOf(" ", $width))
            foreach ($c in $cands) { if ($c -gt 40) { $cut = $c } }
            $head = $rest.Substring(0, $cut + 1)
            if ($first) { if ($Color) { Write-Host $pad$head -ForegroundColor $Color } else { Write-Host $pad$head } }
            else { Write-Host (" " * 6)$head }
            $rest = $rest.Substring($cut + 1)
            $first = $false
        }
        if ($rest -ne "") {
            if ($first) { if ($Color) { Write-Host $pad$rest -ForegroundColor $Color } else { Write-Host $pad$rest } }
            else { Write-Host (" " * 6)$rest }
        }
    }
}

# Кодовую страницу консоли здесь НЕ меняем: chcp 65001 переключил бы и cmd,
# запускаемый из этого окна, и тот начал бы читать файлы очереди как UTF-8
# вместо OEM - кириллица в путях снова бы испортилась. Write-Host сам
# перекодирует .NET-строку в текущую страницу, поэтому в кадре кириллица
# отображается корректно без переключения.

# schtasks запускает задачу в C:\Windows\System32, а все команды задания
# используют относительные пути от каталога синхронизации. Без этого
# "cd /d OS2\..." падает с "путь не найден".
Set-Location "C:\lab3"

Clear-Host
Write-Host "DRIVER LR3 - Windows" -ForegroundColor Green
Write-Host "queue: $QUEUE" -ForegroundColor DarkGray
Write-Host "waiting for commands..." -ForegroundColor Green
Write-Host ""
W "драйвер запущен, ждём очередь"

while ($true) {
    $cmdFile = Get-ChildItem "$QUEUE\*.cmd" -ErrorAction SilentlyContinue |
               Sort-Object Name | Select-Object -First 1
    if (-not $cmdFile) { Start-Sleep -Milliseconds 400; continue }

    # Кодировка консоли (866 или 1251) - угадывать нельзя: на этой машине
    # русские пути читаются только в фактической OEM-кодировке окна.
    $oenc = [System.Text.Encoding]::GetEncoding([int][Console]::OutputEncoding.CodePage)

    $num  = $cmdFile.BaseName.Split('_')[0]
    $slug = $cmdFile.BaseName.Substring($num.Length + 1)
    $inFile = "$QUEUE\$num`_$slug.in"
    # Оператор кладёт .cmd в кодировке консоли; читаем байты явно, иначе
    # PowerShell угадывает ANSI и ломает кириллицу в путях ещё до запуска.
    $cmd = ($oenc.GetString([System.IO.File]::ReadAllBytes($cmdFile.FullName))).Trim()

    # Спец-режим @gui: команда открывает своё окно (дочерний процесс с
    # CREATE_NEW_CONSOLE). После её выполнения консоль драйвера НЕ
    # перерисовывается и не выводится на передний план — снимок делается
    # поверх окна, которое открыла команда.
    $isGui = $false
    $isWin = $false
    if ($cmd.StartsWith('@gui')) { $isGui = $true; $cmd = $cmd.Substring(4).TrimStart() }
    $winProc = ""
    if ($cmd.StartsWith('@win|')) {
        $isWin = $true
        $nl = $cmd.IndexOf("`n")
        if ($nl -lt 0) { $nl = $cmd.Length }
        $winProc = $cmd.Substring(5, $nl - 5).Trim()
        $cmd = if ($nl -lt $cmd.Length) { $cmd.Substring($nl + 1).TrimStart() } else { "" }
    }

    W ("flags win=$isWin gui=$isGui head=[" + $cmd.Substring(0, [Math]::Min(12, $cmd.Length)) + "]")
    W "взята команда $num`_$slug"
    Remove-Item $cmdFile.FullName -Force

    # Run the command through a temporary .cmd written in the OEM code page.
    # Passing the command as an argument to `cmd /c` loses Cyrillic: the
    # argument arrives in OEM encoding, so task_01i\Русский turns to mojibake.
    # Writing it to a file in CP866 first keeps the Cyrillic intact.
    $outFile = "$SYNC\tmp_out.txt"
    $runFile = "$SYNC\tmp_run.cmd"
    $enc = [System.Text.Encoding]::GetEncoding([int][Console]::OutputEncoding.CodePage)

    # Ввод и перенаправление записываем внутрь самого .cmd.
    # Если поставить ">" в PowerShell, он выполнит Out-File и запишет вывод
    # в UTF-16LE (с нулями между символами); если передать строку с кавычками
    # аргументом cmd /c, разбор команды ломается и вывод получается пустым.
    $inSpec = ""
    if (Test-Path $inFile) {
        $inSpec = " < `"$inFile`""
    }
    # Перенаправление ставим на КАЖДУЮ часть цепочки "&", а не один раз в конце.
    # В конце строки ">" действует только на последний элемент, и вывод
    # предыдущих команд (for, if, echo) уходил в stdout и терялся.
    # Обёртка в скобки тоже не годится: %PATH% содержит "Program Files (x86)",
    # и закрывающая скобка в данных обрывала блок - вывод получался пустым.
    # Разделитель ставим в КОНЕЦ предыдущей строки: строка, начинающаяся
    # с "&", cmd выполняет как "пустая команда и следующая", и следующая
    # вместе со своим перенаправлением не отрабатывает - файл остаётся
    # с выводом только первой части цепочки.
    $parts = [regex]::Split($cmd, '(&&|&)')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('@echo off')
    $first = $true
    foreach ($part in $parts) {
        if ($part -match '^&+$') { continue }
        if ($part.Trim() -eq '') { continue }
        if ($first) {
            [void]$sb.Append("`r`n")
            $first = $false
            [void]$sb.Append($part.Trim() + $inSpec + ' > "' + $outFile + '" 2>&1')
        } else {
            [void]$sb.Append(' &')
            [void]$sb.Append("`r`n")
            [void]$sb.Append($part.Trim() + $inSpec + ' >> "' + $outFile + '" 2>&1')
        }
    }
    [void]$sb.Append("`r`n")
    $body = $sb.ToString()
    [System.IO.File]::WriteAllText($runFile, $body, $enc)

    W "запуск $runFile, тело $body".Replace("`r`n", " / ")

    if ($isWin) {
        [W32]::Focus()
        Start-Sleep -Milliseconds 300
        cmd /c call $runFile | Out-Null
        Start-Sleep -Milliseconds 1200
        $hw = [IntPtr]::Zero
        $proc = Get-Process -Name $winProc -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($proc) {
            $hw = $proc.MainWindowHandle
            [void][W32]::ShowWindow($hw, 9)
            [void][W32]::SetForegroundWindow($hw)
            Start-Sleep -Milliseconds 700
        } else { W "process window not found: $winProc" }
        W "снимок (win) $num`_$slug"
        try { Take-Shot "$SHOTS\$num`_$slug.png" -Hwnd $hw } catch { W ("SHOT FAILED: " + $_.Exception.Message) }
        $out = ""
        if (Test-Path $outFile) { $out = $oenc.GetString([System.IO.File]::ReadAllBytes($outFile)); Remove-Item $outFile -Force }
        if ($null -eq $out) { $out = "" }
        $txt = "### COMMAND: $cmd`r`n### OUTPUT:`r`n" + $out.TrimEnd() + "`r`n"
        Set-Content "$DONE\$num.txt" $txt -Encoding UTF8
        Set-Content "$DONE\$num.done" "ok" -Encoding ASCII
        W "готово $num"
        continue
    }
    if ($isGui) {
        # Рисуем промпт ДО запуска (консоль ещё в фокусе), затем запускаем:
        # окно команды появится поверх и попадёт в снимок.
        [W32]::Focus()
        Start-Sleep -Milliseconds 400
        Clear-Host
        Write-Wrapped "[User-6d4ec851@DESKTOP-9KMRHJ8 OS3]`$ $cmd" -Color Green -Indent 0
        Write-Host ""
        cmd /c call $runFile
        Start-Sleep -Milliseconds 1000
        W "снимок (gui) $num`_$slug"
        try { Take-Shot "$SHOTS\$num`_$slug.png" -FullScreen } catch { W ("SHOT FAILED: " + $_.Exception.Message) }
        $out = ""
        if (Test-Path $outFile) {
            $out = $oenc.GetString([System.IO.File]::ReadAllBytes($outFile))
            Remove-Item $outFile -Force
        }
        if ($null -eq $out) { $out = "" }
        $txt = "### COMMAND: $cmd`r`n### OUTPUT:`r`n" + $out.TrimEnd() + "`r`n"
        Set-Content "$DONE\$num.txt" $txt -Encoding UTF8
        Set-Content "$DONE\$num.done" "ok" -Encoding ASCII
        W "готово $num"
        continue
    }

    cmd /c call $runFile
    W "команда выполнена"

    $out = ""
    if (Test-Path $outFile) {
        $out = $oenc.GetString([System.IO.File]::ReadAllBytes($outFile))
        Remove-Item $outFile -Force
    }
    if ($null -eq $out) { $out = "" }
    $out = $out.TrimEnd()

    # The console window must be active before repainting: while it is in the
    # background, Clear-Host/Write-Host are deferred and the screenshot ends up
    # showing the previous command instead of the current one.
    [W32]::Focus()
    Start-Sleep -Milliseconds 400

    # Build the visible frame: prompt, typed input, output.
    # Long paths do not wrap in the console, so wrap them ourselves,
    # otherwise the right part of the command is cut off in the screenshot.
    Clear-Host
    $prompt = "[User-6d4ec851@DESKTOP-9KMRHJ8 OS3]`$ $cmd"
    Write-Wrapped $prompt -Color Green -Indent 0
    if (Test-Path $inFile) {
        Write-Host ($oenc.GetString([System.IO.File]::ReadAllBytes($inFile)).TrimEnd())
    }
    Write-Host ""
    if ($out -ne "") { Write-Wrapped $out }
    Write-Host ""

    # save the text output for the report
    $txt = "### COMMAND: $cmd`r`n"
    if (Test-Path $inFile) {
        $txt += "### INPUT:`r`n" + $oenc.GetString([System.IO.File]::ReadAllBytes($inFile)) + "`r`n"
    }
    $txt += "### OUTPUT:`r`n" + $out + "`r`n"
    Set-Content "$DONE\$num.txt" $txt -Encoding UTF8

    Start-Sleep -Milliseconds 1500
    W "снимок $num`_$slug"
    try { Take-Shot "$SHOTS\$num`_$slug.png" } catch { W ("SHOT FAILED: " + $_.Exception.Message) }
    Set-Content "$DONE\$num.done" "ok" -Encoding ASCII
    W "готово $num"
    Write-Host ""
    Write-Host "[$num] $slug done" -ForegroundColor DarkGray
}
