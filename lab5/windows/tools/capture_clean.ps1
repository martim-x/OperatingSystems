# capture_clean.ps1 - clean frame capture for OS lab 5 (Windows x64)
# Runs hidden (no console of its own visible). Each measured program gets its own
# console window titled with the executable name; frames contain only the prompt
# and the program output.
#
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File capture_clean.ps1 -Step b1
# steps: a, x, b1, b2, b3, c1, c2, c3

[CmdletBinding()]
param(
    [string]$Work = 'C:\Users\User-6d4ec851\OS5\lab5\windows\tools',
    [string]$Step = 'a',
    [int]$RingPollMs = 700,
    [switch]$WaitPe
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lab_common.ps1')
Initialize-LabNative
Initialize-LabDpi

$shots = Join-Path $Work 'shots'
$logs = Join-Path $Work 'logs'
foreach ($d in @($shots, $logs)) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

$script:LogPath = Join-Path $logs ($Step + '_log.txt')
function L([string]$m) {
    $line = ('{0} {1}' -f (Get-Date -Format 'HH:mm:ss.fff'), $m)
    Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
}
Set-Content -LiteralPath $script:LogPath -Value ('step=' + $Step) -Encoding UTF8

$area = Get-LabWorkingArea
L ('area: ' + $area.Left + ',' + $area.Top + ' ' + $area.Width + 'x' + $area.Height)
$ncpu = Get-LabProcessorCount

function ShotRegion([string]$Path, [int]$X, [int]$Y, [int]$W, [int]$H) {
    Initialize-LabDpi
    if ($W -le 0 -or $H -le 0) { throw ('bad region ' + $W + 'x' + $H + ' for ' + $Path) }
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.CopyFromScreen($X, $Y, 0, 0, (New-Object System.Drawing.Size($W, $H)))
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $g.Dispose(); $bmp.Dispose() }
    if (-not (Test-LabFrameFile -Path $Path)) { throw ('frame not saved: ' + $Path) }
    L ('shot ' + (Split-Path -Leaf $Path) + ' ' + $W + 'x' + $H)
}

function GetWinRect($win) {
    $r = New-Object LabWin32+RECT
    [void][LabWin32]::GetWindowRect($win.Handle, [ref]$r)
    return [pscustomobject]@{ X = $r.Left; Y = $r.Top; W = [int]($r.Right - $r.Left); H = [int]($r.Bottom - $r.Top) }
}

function ShotWindow([string]$Path, $win) {
    $r = GetWinRect $win
    $inset = 8
    $w = $r.W - 2 * $inset
    $h = $r.H - 2 * $inset
    ShotRegion -Path $Path -X ($r.X + $inset) -Y ($r.Y + $inset) -W $w -H $h
}

function Start-Console([string]$exe, [string[]]$argv, [int]$X, [int]$Y, [int]$W, [int]$H) {
    $cmd = 'title ' + $exe + ' & cd /d "' + $Work + '" & ' + $exe
    if ($argv -and $argv.Count -gt 0) { $cmd += ' ' + ($argv -join ' ') }
    $p = Start-Process -FilePath $env:ComSpec -ArgumentList ('/k "' + $cmd + '"') -PassThru -WorkingDirectory $Work
    try { $p.PriorityClass = 'Normal' } catch { L ('priority Normal failed: ' + $_.Exception.Message) }
    Start-Sleep -Milliseconds 600
    $win = Wait-LabWindow -ProcessId $p.Id -TimeoutMs 12000
    if (-not $win) { throw ('window not found for ' + $exe) }
    [void](Set-LabWindowRect -Handle $win.Handle -X $X -Y $Y -Width $W -Height $H)
    Assert-TopMost $win
    L ('started ' + $exe + ' ' + ($argv -join ' ') + ' shell pid ' + $p.Id)
    return [pscustomobject]@{ Shell = $p; Window = $win }
}

function Get-ExePid([int]$ShellPid, [string]$Name, [int]$TimeoutSec = 10) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $c = @(Get-CimInstance -ClassName Win32_Process -Filter ('ParentProcessId=' + $ShellPid) -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like ($Name + '*') })
        if ($c.Count -ge 1) { return [int]$c[0].ProcessId }
        Start-Sleep -Milliseconds 150
    }
    return 0
}

function Close-Console($console) {
    if (-not $console) { return }
    try { [void][LabWin32]::ShowWindow($console.Window.Handle, 0) } catch { }
    try { Stop-Process -Id $console.Shell.Id -Force -ErrorAction SilentlyContinue } catch { }
}

function Wait-PeWindow([int[]]$Pids, [string]$Work, [int]$TimeoutSec = 75) {
    $go = Join-Path $Work 'pe_go.flag'
    $done = Join-Path $Work 'pe_done.flag'
    Remove-Item -LiteralPath $done -Force -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $go -Value (($Pids -join ' ')) -Encoding ASCII
    L ('PE window: pids ' + ($Pids -join ','))
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $done) { break }
        Start-Sleep -Milliseconds 300
    }
    Remove-Item -LiteralPath $go -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $done -Force -ErrorAction SilentlyContinue
    L 'PE window: continue'
}

function Get-ConsoleWindow([int]$OwnerPid, [int]$TimeoutSec = 20, [int64[]]$Exclude = @()) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $cands = @([LabWin32]::VisibleWindows() | Where-Object {
            $_.Title -like '*Lab-05x*' -and -not ($Exclude -contains $_.Handle.ToInt64())
        })
        if ($cands.Count -gt 0) {
            $hosts = @(Get-CimInstance -ClassName Win32_Process -Filter "Name='conhost.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.ParentProcessId -eq $OwnerPid })
            foreach ($h in $hosts) {
                $own = @($cands | Where-Object { $_.ProcessId -eq [uint32]$h.ProcessId })
                if ($own.Count -gt 0) { return $own[0] }
            }
            return $cands[0]
        }
        Start-Sleep -Milliseconds 200
    }
    return $null
}

function Assert-TopMost($win) {
    if (-not $win) { return }
    try { [void][LabWin32]::SetForegroundWindow($win.Handle) } catch { }
    try {
        [void][LabWin32]::SetWindowPos($win.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x0003)
    } catch { L ('topmost failed: ' + $_.Exception.Message) }
    Start-Sleep -Milliseconds 120
}

function ConvertMask([string]$v) {
    if ($v -eq 'all') {
        if ($ncpu -ge 63) { return [int64]-1 }
        return [int64]([math]::Pow(2, $ncpu) - 1)
    }
    return [int64]$v
}

# ---------------------------------------------------------------- steps

if ($Step -eq 'a') {
    $w = [int]($area.Width * 0.62)
    $c = Start-Console 'Lab-05a.exe' @() $area.Left $area.Top $w $area.Height
    Start-Sleep -Milliseconds 1200
    ShotWindow (Join-Path $shots '02_a.png') $c.Window
    Close-Console $c
    exit 0
}

if ($Step -eq 'x') {
    $w = [int]($area.Width * 0.62)
    $c = Start-Console 'Lab-05x.exe' @() $area.Left $area.Top $w $area.Height
    $pidX = Get-ExePid $c.Shell.Id 'Lab-05x.exe'
    L ('Lab-05x pid ' + $pidX)
    Start-Sleep -Seconds 18
    ShotWindow (Join-Path $shots '03_x_mid.png') $c.Window
    $deadline = (Get-Date).AddSeconds(180)
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-LabProcessAlive -ProcessId $pidX)) { break }
        Start-Sleep -Milliseconds 500
    }
    Start-Sleep -Milliseconds 700
    ShotWindow (Join-Path $shots '03_x.png') $c.Window
    L 'Lab-05x finished'
    Close-Console $c
    exit 0
}

if ($Step -like 'b*') {
    $table = @{
        'b1' = @('all', 'Normal', 'Normal')
        'b2' = @('all', 'BelowNormal', 'High')
        'b3' = @('1', 'BelowNormal', 'High')
    }
    if (-not $table.ContainsKey($Step)) { throw ('unknown step ' + $Step) }
    $p1, $p2, $p3 = $table[$Step]
    $mask = ConvertMask $p1
    $tag = '05b_s' + $Step.Substring(1)

    $half = [int]($area.Width / 2)
    $parentH = [int]$area.Height
    $childH = [int](($area.Height) / 2)

    $c = Start-Console 'Lab-05b.exe' @([string]$mask, $p2, $p3) $area.Left $area.Top $half $parentH
    $pidB = Get-ExePid $c.Shell.Id 'Lab-05b.exe'
    L ('Lab-05b pid ' + $pidB + ' mask ' + $mask + ' ' + $p2 + '/' + $p3)

    $kids = @()
    $deadline = (Get-Date).AddSeconds(25)
    while ((Get-Date) -lt $deadline) {
        $kids = @(Get-LabChildren -ParentId $pidB -NamePattern 'Lab-05x*')
        if ($kids.Count -ge 2) { break }
        Start-Sleep -Milliseconds 200
    }
    if ($kids.Count -lt 2) { throw ('children found: ' + $kids.Count) }
    $kidIds = @($kids | ForEach-Object { [int]$_.ProcessId })
    L ('children ' + ($kidIds -join ', '))
    if ($WaitPe) {
        Start-Sleep -Seconds 3
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Work 'pe_frame_rows.ps1') -Text 'Lab-05' -RowClick 1 -Shot (Join-Path $shots ($tag + '_f_procexp.png')) -RowClick2 2 -Shot2 (Join-Path $shots ($tag + '_f_procexp2.png')) -LogPath (Join-Path $logs ($tag + '_pe.txt'))
        L 'pe frame done'
    }

    $wins = @()
    $usedHandles = @()
    for ($i = 0; $i -lt 2; $i++) {
        $w = Get-ConsoleWindow -OwnerPid $kidIds[$i] -TimeoutSec 25 -Exclude $usedHandles
        if ($w) { $usedHandles += $w.Handle.ToInt64() }
        if (-not $w) { L ('window not found for child ' + $kidIds[$i]); continue }
        $y = $area.Top + $i * $childH
        [void](Set-LabWindowRect -Handle $w.Handle -X ($area.Left + $half) -Y $y -Width $half -Height $childH)
        Assert-TopMost $w
        $wins += $w
    }

    Start-Sleep -Seconds 3
    ShotRegion -Path (Join-Path $shots ($tag + '_a_start.png')) -X $area.Left -Y $area.Top -W $area.Width -H $area.Height
    Start-Sleep -Seconds 9
    ShotRegion -Path (Join-Path $shots ($tag + '_c_mid.png')) -X ($area.Left + $half) -Y $area.Top -W $half -H $area.Height

    $ringTmp = Join-Path $shots ('_ring_' + $tag + '.tmp.png')
    $ringLast = Join-Path $shots ('_ring_' + $tag + '.png')
    $ring = Invoke-LabRingLoop -Probe {
        foreach ($cid in $kidIds) { if (-not (Test-LabProcessAlive -ProcessId $cid)) { return [int]$cid } }
        if (-not (Test-LabProcessAlive -ProcessId $pidB)) { return -1 }
        return 0
    } -Capture {
        param($FramePath)
        ShotRegion -Path $FramePath -X ($area.Left + $half) -Y $area.Top -W $half -H $area.Height
    } -TmpPath $ringTmp -LastPath $ringLast -TimeoutSec 300 -PollMs $RingPollMs -OnLog { param($t) L $t }

    L ('ring: frames=' + $ring.Frames + ' dead=' + $ring.DeadFrames + ' failures=' + $ring.Failures + ' stopped=' + $ring.Stopped + ' first=' + $ring.FirstGone + ' elapsed=' + $ring.ElapsedSec)
    $firstAt = Get-Date
    if ($ring.Frames -gt 0 -and (Test-LabFrameFile -Path $ringLast)) {
        Copy-Item -LiteralPath $ringLast -Destination (Join-Path $shots ($tag + '_d_first_finish.png')) -Force
        L 'd_first_finish copied from ring'
    }
    Start-Sleep -Milliseconds 400
    foreach ($cid in $kidIds) {
        if (Test-LabProcessAlive -ProcessId $cid) {
            $w = Get-ConsoleWindow -OwnerPid $cid -TimeoutSec 4
            if ($w) { [void](Set-LabWindowRect -Handle $w.Handle -X ($area.Left + $half) -Y $area.Top -Width $half -Height $area.Height); Assert-TopMost $w }
        }
    }
    Start-Sleep -Milliseconds 200
    ShotRegion -Path (Join-Path $shots ($tag + '_d2_after_exit.png')) -X ($area.Left + $half) -Y $area.Top -W $half -H $area.Height

    $deadline = (Get-Date).AddSeconds(300)
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-LabProcessAlive -ProcessId $pidB)) { break }
        Start-Sleep -Milliseconds 500
    }
    Start-Sleep -Milliseconds 900
    ShotRegion -Path (Join-Path $shots ($tag + '_e_finish.png')) -X $area.Left -Y $area.Top -W $half -H $parentH
    L ('e_finish region ' + $half + 'x' + $parentH)
    L ('parent finished, first gone ' + $ring.FirstGone + ' at ' + $firstAt.ToString('HH:mm:ss.fff'))

    Close-Console $c
    foreach ($cid in $kidIds) { Stop-Process -Id $cid -Force -ErrorAction SilentlyContinue }
    foreach ($f in @($ringTmp, $ringLast)) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }
    exit 0
}

if ($Step -like 'c*') {
    $table = @{
        'c1' = @('all', 'Normal', 'Normal', 'Normal')
        'c2' = @('all', 'Normal', 'Lowest', 'Highest')
        'c3' = @('1', 'Normal', 'Lowest', 'Highest')
    }
    if (-not $table.ContainsKey($Step)) { throw ('unknown step ' + $Step) }
    $p1, $p2, $p3, $p4 = $table[$Step]
    $mask = ConvertMask $p1
    $tag = '05c_s' + $Step.Substring(1)

    $w = [int]($area.Width * 0.60)
    $c = Start-Console 'Lab-05c.exe' @([string]$mask, $p2, $p3, $p4) $area.Left $area.Top $w $area.Height
    $pidC = Get-ExePid $c.Shell.Id 'Lab-05c.exe'
    L ('Lab-05c pid ' + $pidC + ' mask ' + $mask + ' ' + $p2 + ' ' + $p3 + ' ' + $p4)

    Start-Sleep -Seconds 2
    $sel = $null
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        $p = Get-Process -Id $pidC -ErrorAction SilentlyContinue
        if ($p) {
            $sel = Select-LabWorkerThreadIds -Threads $p.Threads -P3 $p3 -P4 $p4
            if ($sel -and $sel.ThreadIds.Count -eq 2) { break }
        }
        Start-Sleep -Milliseconds 300
    }
    if (-not $sel -or $sel.ThreadIds.Count -ne 2) { throw ('worker threads not identified: ' + $sel.Error) }
    $workerTids = @($sel.ThreadIds)
    L ('worker tids ' + ($workerTids -join ', '))
    if ($WaitPe) {
        Start-Sleep -Seconds 2
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Work 'pe_frame_rows.ps1') -Text 'Lab-05' -RowClick 1 -Shot (Join-Path $shots ($tag + '_f_procexp.png')) -LogPath (Join-Path $logs ($tag + '_pe.txt'))
        L 'pe frame done'
    }

    Start-Sleep -Seconds 2
    ShotWindow (Join-Path $shots ($tag + '_a_start.png')) $c.Window
    Start-Sleep -Seconds 8
    ShotWindow (Join-Path $shots ($tag + '_c_mid.png')) $c.Window

    $ringTmp = Join-Path $shots ('_ring_' + $tag + '.tmp.png')
    $ringLast = Join-Path $shots ('_ring_' + $tag + '.png')
    $ring = Invoke-LabRingLoop -Probe {
        $cur = @()
        try { $cur = @(Get-LabThreadIds -ProcessId $pidC) } catch { }
        if ($cur.Count -eq 0) { return -1 }
        $snap = Get-LabWorkerExitSnapshot -WorkerTids $workerTids -CurrentTids $cur
        if ($snap.Status -eq 'first') { return [int]$snap.FirstGone }
        if ($snap.Status -eq 'ambiguous') { return -2 }
        return 0
    } -Capture {
        param($FramePath)
        ShotWindow -Path $FramePath -win $c.Window
    } -TmpPath $ringTmp -LastPath $ringLast -TimeoutSec 300 -PollMs $RingPollMs -OnLog { param($t) L $t }

    L ('ring: frames=' + $ring.Frames + ' dead=' + $ring.DeadFrames + ' failures=' + $ring.Failures + ' stopped=' + $ring.Stopped + ' first=' + $ring.FirstGone + ' elapsed=' + $ring.ElapsedSec)
    if ($ring.Frames -gt 0 -and (Test-LabFrameFile -Path $ringLast)) {
        Copy-Item -LiteralPath $ringLast -Destination (Join-Path $shots ($tag + '_d_first_finish.png')) -Force
        L 'd_first_finish copied from ring'
    }
    Start-Sleep -Milliseconds 400
    ShotWindow (Join-Path $shots ($tag + '_d2_after_exit.png')) $c.Window

    $deadline = (Get-Date).AddSeconds(300)
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-LabProcessAlive -ProcessId $pidC)) { break }
        Start-Sleep -Milliseconds 500
    }
    Start-Sleep -Milliseconds 900
    ShotWindow (Join-Path $shots ($tag + '_e_finish.png')) $c.Window
    L ('finished, first gone ' + $ring.FirstGone)

    Close-Console $c
    Stop-Process -Id $pidC -Force -ErrorAction SilentlyContinue
    foreach ($f in @($ringTmp, $ringLast)) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }
    exit 0
}

throw ('unknown step ' + $Step)
