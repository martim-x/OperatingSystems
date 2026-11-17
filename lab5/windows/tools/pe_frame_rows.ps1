param(
    [string]$Text = 'Lab-05',
    [string]$Shot = '',
    [string]$Shot2 = '',
    [int]$RowClick = 2,
    [int]$RowClick2 = 3,
    [string]$Pe = 'C:\Tools\ProcessExplorer\procexp64.exe',
    [string]$LogPath = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lab_common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class PEG {
  public delegate bool Proc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, Proc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")] public static extern IntPtr SendMessageStr(IntPtr h, uint m, IntPtr w, string l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
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
[void][PEG]::ShowWindow($h, 3)
[void][PEG]::MoveWindow($h, 40, 40, 1150, 690, $true)
Start-Sleep -Milliseconds 900

$script:edit = [IntPtr]::Zero
$script:tree = [IntPtr]::Zero
$cb = [PEG+Proc]{
    param($ch, $l)
    $c = New-Object System.Text.StringBuilder 128
    [void][PEG]::GetClassName($ch, $c, 128)
    if ($c.ToString() -eq 'Edit') { $script:edit = $ch }
    if ($c.ToString() -eq 'TreeListWindowClass') { $script:tree = $ch }
    return $true
}
[void][PEG]::EnumChildWindows($h, $cb, [IntPtr]::Zero)
if ($script:edit -eq [IntPtr]::Zero) { throw 'filter edit not found' }
if ($script:tree -eq [IntPtr]::Zero) { throw 'tree not found' }
[void][PEG]::SendMessageStr($script:edit, 0x000C, [IntPtr]::Zero, $Text)
Start-Sleep -Milliseconds 1200
[void][PEG]::SendMessageStr($script:edit, 0x000C, [IntPtr]::Zero, '')
Start-Sleep -Milliseconds 200
[void][PEG]::SendMessageStr($script:edit, 0x000C, [IntPtr]::Zero, $Text)
Start-Sleep -Milliseconds 1200
L ('filter ' + $Text)

function Click-Row([IntPtr]$Tree, [int]$Row) {
    if ($Row -le 0) { return }
    $y = Get-LabPeRowClickY -Row $Row
    $x = 260
    $lp = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
    [void][PEG]::SendMessage($Tree, 0x0201, [IntPtr]1, $lp)
    Start-Sleep -Milliseconds 90
    [void][PEG]::SendMessage($Tree, 0x0202, [IntPtr]0, $lp)
    Start-Sleep -Milliseconds 700
}
function Shot([string]$Path) {
    if (-not $Path) { return }
    $r = New-Object PEG+RECT
    [void][PEG]::GetWindowRect($h, [ref]$r)
    $w = $r.Right - $r.Left
    $hh = $r.Bottom - $r.Top
    $bmp = New-Object System.Drawing.Bitmap($w, $hh)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [void][PEG]::PrintWindow($h, $hdc, 2)
    $g.ReleaseHdc($hdc)
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    L ('shot ' + (Split-Path -Leaf $Path) + ' ' + $w + 'x' + $hh)
}

Click-Row $script:tree $RowClick
Shot $Shot
if ($Shot2) {
    Click-Row $script:tree $RowClick2
    Shot $Shot2
}
L 'done'
