param(
    [int]$Row = 2,
    [string]$Shot = '',
    [string]$Pe = 'C:\Tools\ProcessExplorer\procexp64.exe'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class PPR {
  public delegate bool Proc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, Proc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(Proc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$p = Get-Process procexp64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { throw 'PE not running' }
$peId = [uint32]$p.Id
$script:tree = [IntPtr]::Zero
$cb = [PPR+Proc]{
    param($ch, $l)
    $c = New-Object System.Text.StringBuilder 128
    [void][PPR]::GetClassName($ch, $c, 128)
    if ($c.ToString() -eq 'TreeListWindowClass') { $script:tree = $ch }
    return $true
}
[void][PPR]::EnumChildWindows($p.MainWindowHandle, $cb, [IntPtr]::Zero)
if ($script:tree -eq [IntPtr]::Zero) { throw 'tree not found' }

$y = 16 + ($Row - 1) * 19
$lp = [IntPtr](($y -shl 16) -bor (260 -band 0xFFFF))
foreach ($i in 1..1) {
    [void][PPR]::SendMessage($script:tree, 0x0201, [IntPtr]1, $lp)
    Start-Sleep -Milliseconds 60
    [void][PPR]::SendMessage($script:tree, 0x0202, [IntPtr]0, $lp)
    Start-Sleep -Milliseconds 120
}
Start-Sleep -Milliseconds 1200

$script:dlg = [IntPtr]::Zero
$cb2 = [PPR+Proc]{
    param($h, $l)
    $c = New-Object System.Text.StringBuilder 64
    [void][PPR]::GetClassName($h, $c, 64)
    $t = New-Object System.Text.StringBuilder 256
    [void][PPR]::GetWindowText($h, $t, 256)
    $wpid = [uint32]0
    [void][PPR]::GetWindowThreadProcessId($h, [ref]$wpid)
    if ($t.ToString() -like '*Properties*' -and $wpid -eq $peId) { $script:dlg = $h }
    return $true
}
[void][PPR]::EnumWindows($cb2, [IntPtr]::Zero)
if ($script:dlg -eq [IntPtr]::Zero) { throw 'properties dialog not found' }

if ($Shot) {
    $r = New-Object PPR+RECT
    [void][PPR]::GetWindowRect($script:dlg, [ref]$r)
    $w = $r.Right - $r.Left
    $hh = $r.Bottom - $r.Top
    $bmp = New-Object System.Drawing.Bitmap($w, $hh)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [void][PPR]::PrintWindow($script:dlg, $hdc, 2)
    $g.ReleaseHdc($hdc)
    $bmp.Save($Shot, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    'shot ' + $Shot + ' ' + $w + 'x' + $hh
}
$title = New-Object System.Text.StringBuilder 256
[void][PPR]::GetWindowText($script:dlg, $title, 256)
'title: ' + $title.ToString()
[void][PPR]::SendMessage($script:dlg, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
