param(
    [string]$Text = 'Lab-05',
    [string]$Shot = '',
    [string]$Pe = 'C:\Tools\ProcessExplorer\procexp64.exe',
    [string]$LogPath = ''
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class PEF {
  public delegate bool Proc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, Proc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")] public static extern IntPtr SendMessageStr(IntPtr h, uint m, IntPtr w, string l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
function L([string]$m) {
    if ($LogPath) { Add-Content -LiteralPath $LogPath -Value (('{0} {1}' -f (Get-Date -Format 'HH:mm:ss.fff'), $m)) -Encoding UTF8 }
}

$p = Get-Process procexp64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) {
    Start-Process -FilePath $Pe | Out-Null
    $deadline = (Get-Date).AddSeconds(25)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 400
        $p = Get-Process procexp64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($p) { break }
    }
    L 'started PE'
}
if (-not $p) { throw 'PE not running' }
$h = $p.MainWindowHandle
[void][PEF]::ShowWindow($h, 3)
[void][PEF]::MoveWindow($h, 0, 0, 3440, 1392, $true)
Start-Sleep -Milliseconds 900

$found = [IntPtr]::Zero
$cb = [PEF+Proc]{
    param($ch, $l)
    $c = New-Object System.Text.StringBuilder 128
    [void][PEF]::GetClassName($ch, $c, 128)
    if ($c.ToString() -eq 'Edit') { $script:found = $ch }
    return $true
}
[void][PEF]::EnumChildWindows($h, $cb, [IntPtr]::Zero)
if ($found -eq [IntPtr]::Zero) { throw 'filter edit not found' }
[void][PEF]::SendMessageStr($found, 0x000C, [IntPtr]::Zero, $Text)
Start-Sleep -Milliseconds 1200
[void][PEF]::SendMessageStr($found, 0x000C, [IntPtr]::Zero, $Text)
Start-Sleep -Milliseconds 900
L ('filter ' + $Text)

if ($Shot) {
    $r = New-Object PEF+RECT
    [void][PEF]::GetWindowRect($h, [ref]$r)
    $w = $r.Right - $r.Left
    $hh = $r.Bottom - $r.Top
    $bmp = New-Object System.Drawing.Bitmap($w, $hh)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [void][PEF]::PrintWindow($h, $hdc, 2)
    $g.ReleaseHdc($hdc)
    $bmp.Save($Shot, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    L ('shot ' + (Split-Path -Leaf $Shot) + ' ' + $w + 'x' + $hh)
}
L 'done'
