$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
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

$SHOTS = "C:\lab3_sync\shots"
$LOG   = "C:\lab3_sync\gui.log"
function L([string]$m) { Add-Content -Path $LOG -Value ("{0} {1}" -f (Get-Date -Format "HH:mm:ss"), $m) -Encoding UTF8 }

function Shot([string]$procName, [string]$path, [double]$scale = 1.0) {
    $p = Get-Process -Name $procName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $p) { L "no window for $procName"; return }
    $h = $p.MainWindowHandle
    $r = New-Object W32+RECT
    if (-not [W32]::GetWindowRect($h, [ref]$r)) { L "GetWindowRect failed for $procName"; return }
    $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
    if ($w -lt 100 -or $ht -lt 100) { L "bad rect $w x $ht"; return }
    $bmp = New-Object System.Drawing.Bitmap $w, $ht
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size $w, $ht))
    $g.Dispose()
    if ($scale -ne 1.0) {
        $big = New-Object System.Drawing.Bitmap ([int]($w * $scale)), ([int]($ht * $scale))
        $gg = [System.Drawing.Graphics]::FromImage($big)
        $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gg.DrawImage($bmp, 0, 0, $big.Width, $big.Height)
        $gg.Dispose(); $bmp.Dispose(); $bmp = $big
    }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    L "shot $path $($bmp.Width)x$($bmp.Height)"
    $bmp.Dispose()
}

function WaitWin([string]$name, [double]$sec) {
    $t = 0.0
    while ($t -lt $sec) {
        $p = Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($p) { return $p }
        Start-Sleep -Milliseconds 400; $t += 0.4
    }
    return $null
}

function SetSearch([IntPtr]$hwnd, [string]$text) {
    try {
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
        $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
        $el = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
        if ($el) {
            $vp = $el.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
            $vp.SetValue($text)
            L "search set: $text"
        } else { L "search edit not found" }
    } catch { L ("SetSearch failed: " + $_.Exception.Message) }
}

function SelectTab([IntPtr]$hwnd, [string]$name) {
    try {
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
        $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)
        $el = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
        if ($el) {
            $sp = $el.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            $sp.Select()
            L "tab selected: $name"
        } else { L "tab not found: $name" }
    } catch { L ("SelectTab failed: " + $_.Exception.Message) }
}

function Cleanup {
    foreach ($n in @("procexp64","Lab-03a","Lab-03x","Lab-03d-server","Lab-03d-client","Taskmgr")) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

$ws = New-Object -ComObject WScript.Shell
Cleanup
L "=== gui pass v4 ==="

# ---------- A: PE tree + parent handles ----------
Start-Process "C:\lab3\Lab-03a.exe" -ArgumentList "300" | Out-Null
Start-Sleep -Seconds 2
L ("lab procs: " + ((Get-Process Lab-03a,Lab-03x -ErrorAction SilentlyContinue | Measure-Object).Count))
Start-Process "C:\Users\User-6d4ec851\Downloads\ProcessExplorer\procexp64.exe" -ArgumentList "/accepteula" | Out-Null
$pe = WaitWin "procexp64" 30
if ($pe) {
    [void][W32]::ShowWindow($pe.MainWindowHandle, 3)
    [void][W32]::SetForegroundWindow($pe.MainWindowHandle)
    Start-Sleep -Seconds 3
    [void]$ws.AppActivate($pe.Id); Start-Sleep -Milliseconds 800
    $ws.SendKeys("Lab-03a"); Start-Sleep -Seconds 2
    Shot "procexp64" "$SHOTS\g08_procexp.png"
    $ws.SendKeys("^l"); Start-Sleep -Milliseconds 900
    $ws.SendKeys("^h"); Start-Sleep -Seconds 2
    Shot "procexp64" "$SHOTS\g16_handles.png"
} else { L "PE window not found" }
Get-Process procexp64,Lab-03a,Lab-03x -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

# ---------- B: Task Manager ----------
Start-Process "C:\lab3\Lab-03a.exe" -ArgumentList "300" | Out-Null
Start-Sleep -Seconds 2
Start-Process "taskmgr.exe" | Out-Null
$tm = WaitWin "Taskmgr" 25
if ($tm) {
    [void][W32]::ShowWindow($tm.MainWindowHandle, 3)
    [void]$ws.AppActivate($tm.Id)
    Start-Sleep -Seconds 2
    SetSearch $tm.MainWindowHandle "Lab-03"
    Start-Sleep -Seconds 2
    Shot "Taskmgr" "$SHOTS\g10_taskmgr_proc.png" 1.6
    SelectTab $tm.MainWindowHandle "Подробности"
    Start-Sleep -Seconds 2
    SetSearch $tm.MainWindowHandle "Lab-03"
    Start-Sleep -Seconds 2
    Shot "Taskmgr" "$SHOTS\g11_taskmgr_details.png" 1.6
} else { L "taskmgr window not found" }
Get-Process Taskmgr,Lab-03a,Lab-03x -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

# ---------- D: pipe handle of Lab-03d-server ----------
Start-Process "C:\lab3\Lab-03d-server.exe" -ArgumentList "3 10 1 500000000" | Out-Null
Start-Sleep -Seconds 3
L ("d procs: " + ((Get-Process Lab-03d-server,Lab-03d-client -ErrorAction SilentlyContinue | Measure-Object).Count))
Start-Process "C:\Users\User-6d4ec851\Downloads\ProcessExplorer\procexp64.exe" -ArgumentList "/accepteula" | Out-Null
$pe2 = WaitWin "procexp64" 30
if ($pe2) {
    [void][W32]::ShowWindow($pe2.MainWindowHandle, 3)
    Start-Sleep -Seconds 2
    [void]$ws.AppActivate($pe2.Id); Start-Sleep -Milliseconds 800
    $ws.SendKeys("Lab-03d-server"); Start-Sleep -Seconds 2
    $ws.SendKeys("^l"); Start-Sleep -Milliseconds 900
    $ws.SendKeys("^h"); Start-Sleep -Seconds 2
    L ("d procs now: " + ((Get-Process Lab-03d-server,Lab-03d-client -ErrorAction SilentlyContinue | Measure-Object).Count))
    Shot "procexp64" "$SHOTS\g15_pipe.png"
} else { L "PE2 window not found" }

Cleanup
L "=== gui pass v4 done ==="
