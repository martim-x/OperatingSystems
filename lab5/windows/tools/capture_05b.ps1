# ============================================================================
# capture_05b.ps1 - съёмка серии для Lab-05b (два дочерних ПРОЦЕССА Lab-05x)
#
#   capture_05b.ps1 -P1 <маска> -P2 <класс> -P3 <класс> -Tag <метка>
#
# P1: "all" (все процессоры) | 0x... | 0b... | десятичное число
# P2, P3: Idle | BelowNormal | Normal | AboveNormal | High | RealTime
#
# Что делает:
#   1) запускает Lab-05b.exe (он сам поднимает два Lab-05x в отдельных окнах);
#   2) ждёт появления дочерних процессов (Win32_Process.ParentProcessId);
#   3) раскладывает окна: родитель сверху справа, дети - двумя этажами ниже,
#      левая половина экрана остаётся драйверу с его консолью;
#   4) кадры: <Tag>_a_start, <Tag>_b_ps (таблица приоритетов/масок),
#      <Tag>_c_mid, <Tag>_d_first_finish (последний кадр перед выходом первого
#      дочернего процесса), <Tag>_d2_after_exit (сразу после выхода),
#      <Tag>_e_finish (после завершения родителя).
#
# Про кадр "момент выхода": консольное окно процесса исчезает вместе с
# процессом, поэтому d_first_finish берётся из кольцевого буфера - это
# последний ПРОВЕРЕННЫЙ кадр, снятый при живом процессе. Если буфер пуст,
# устарел или кадр не записался, скрипт НЕ подставляет снимок уже закрытого
# окна: пишет <Tag>_d_first_finish_MISSING.txt с причиной и завершается
# кодом 5, чтобы провал был виден драйверу и оператору.
# ============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$P1,
    [Parameter(Mandatory = $true)][string]$P2,
    [Parameter(Mandatory = $true)][string]$P3,
    [Parameter(Mandatory = $true)][string]$Tag,
    [string]$Root = '',
    [ValidateSet('right', 'full')][string]$Layout = 'right',
    [int]$StartDelaySec = 3,
    [int]$MidDelaySec = 10,
    [int]$ParentTimeoutSec = 240,
    [int]$RingMaxStaleSec = 5
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lab_common.ps1')
Initialize-LabConsole
Initialize-LabDpi
$script:OriginalTitle = ''
try { $script:OriginalTitle = [string]$Host.UI.RawUI.WindowTitle } catch { }
try { $Host.UI.RawUI.WindowTitle = 'OS5 lab5 capture ' + $Tag } catch { }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$work = Resolve-LabRoot -Requested $Root -Fallback $PSScriptRoot
$shotsDir = Join-Path $work 'shots'
$logsDir = Join-Path $work 'logs'
foreach ($d in @($shotsDir, $logsDir)) {
    if (-not (Test-Path -LiteralPath $d)) { $null = New-Item -ItemType Directory -Path $d -Force }
}
Start-LabLog -Path (Join-Path $logsDir ($Tag + '_info.txt'))

$exe = Join-Path $work 'Lab-05b.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    Write-LabLine ('[!] не найден ' + $exe)
    Write-LabLine '[!] сначала соберите exe: queue\01_build.cmd (MSVC ARM64 Developer Command Prompt)'
    exit 2
}

$known = @('Idle', 'BelowNormal', 'Normal', 'AboveNormal', 'High', 'RealTime')
if ($known -notcontains $P2) { Write-LabLine ('[!] P2=' + $P2 + ' не из списка классов: ' + ($known -join ', ')) }
if ($known -notcontains $P3) { Write-LabLine ('[!] P3=' + $P3 + ' не из списка классов: ' + ($known -join ', ')) }

$mask = ConvertTo-LabMask -Value $P1
$maskText = Format-LabMask -Mask $mask

Write-LabLine ''
Write-LabLine ('=== Lab-05b, серия ' + $Tag + ' ===')
Write-LabLine ('команда: Lab-05b.exe ' + $mask + ' ' + $P2 + ' ' + $P3 + '   (P1 ' + $P1 + ' -> маска ' + $maskText + ')')
Write-LabLine ('число логических процессоров: ' + (Get-LabProcessorCount))

# --- 1. запуск родителя -----------------------------------------------------

$proc = $null
try {
    $childArgs = @([string]$mask, $P2, $P3)
    $proc = Start-Process -FilePath $exe -ArgumentList $childArgs -WorkingDirectory $work -PassThru
} catch {
    Write-LabLine ('[!] не удалось запустить Lab-05b.exe: ' + $_.Exception.Message)
    exit 3
}
Write-LabLine ('родительский процесс: PID ' + $proc.Id)

# --- 2. ожидание двух дочерних процессов -----------------------------------

$children = @()
$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
    $children = @(Get-LabChildren -ParentId $proc.Id -NamePattern 'Lab-05x*')
    if ($children.Count -ge 2) { break }
    if (-not (Test-LabProcessAlive -ProcessId $proc.Id)) { break }
    Start-Sleep -Milliseconds 250
}
if ($children.Count -lt 2) {
    Write-LabLine ('[!] дочерних процессов найдено: ' + $children.Count + ' (ожидалось 2)')
    Write-LabLine '[!] Lab-05b должен запускать Lab-05x.exe через CreateProcess с CREATE_NEW_CONSOLE (см. README, контракт .c)'
}
foreach ($c in $children) {
    Write-LabLine ('  дочерний процесс: PID ' + $c.ProcessId + '  ' + $c.Name)
}
$childIds = @($children | ForEach-Object { [int]$_.ProcessId })

# --- 3. раскладка окон ------------------------------------------------------

$area = Get-LabWorkingArea
$used = New-Object System.Collections.ArrayList

function Place-LabTarget {
    param([int]$TargetId, [int]$X, [int]$Y, [int]$Width, [int]$Height, [string]$Hint = '')

    $win = Wait-LabWindow -ProcessId $TargetId -TimeoutMs 12000 -TitleHint $Hint -Exclude @($used)
    if (-not $win) {
        Write-LabLine ('[!] окно для PID ' + $TargetId + ' не найдено (Windows Terminal вместо conhost.exe? см. README)')
        return $false
    }
    [void]$used.Add($win.Handle.ToInt64())
    [void](Set-LabWindowRect -Handle $win.Handle -X $X -Y $Y -Width $Width -Height $Height)
    Write-LabLine ('[i] окно PID ' + $TargetId + ' -> x=' + $X + ' y=' + $Y + ' ' + $Width + 'x' + $Height)
    return $true
}

$colX = $area.Left
$colW = $area.Width
$parentFrac = 0.20
if ($Layout -eq 'right') {
    $colX = $area.Left + [int][math]::Floor($area.Width * 0.50)
    $colW = $area.Width - [int][math]::Floor($area.Width * 0.50)
    $parentFrac = 0.26
}

$parentH = [int][math]::Floor($area.Height * $parentFrac)
if ($parentH -lt 180) { $parentH = 180 }
$childH = [int][math]::Floor(($area.Height - $parentH) / 2)

[void](Place-LabTarget -TargetId $proc.Id -X $colX -Y $area.Top -Width $colW -Height $parentH -Hint 'Lab-05b')
if ($childIds.Count -ge 1) {
    [void](Place-LabTarget -TargetId $childIds[0] -X $colX -Y ($area.Top + $parentH) -Width $colW -Height $childH -Hint 'Lab-05x')
}
if ($childIds.Count -ge 2) {
    [void](Place-LabTarget -TargetId $childIds[1] -X $colX -Y ($area.Top + $parentH + $childH) -Width $colW -Height ($area.Height - $parentH - $childH) -Hint 'Lab-05x')
}

# --- 4. кадры ---------------------------------------------------------------

Write-LabLine ('[i] старт серии, кадр a_start через ' + $StartDelaySec + ' с')
Start-Sleep -Seconds $StartDelaySec
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_a_start.png')) } catch { Write-LabLine ('[!] кадр a_start: ' + $_.Exception.Message) }

Show-LabProcessTable -ProcessId (@($proc.Id) + $childIds)
Write-LabLine '[i] пауза 1.2 с, чтобы текст успел попасть в консоль драйвера'
Start-Sleep -Milliseconds 1200
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_b_ps.png')) } catch { Write-LabLine ('[!] кадр b_ps: ' + $_.Exception.Message) }

Write-LabLine ('[i] промежуточный кадр через ' + $MidDelaySec + ' с')
Start-Sleep -Seconds $MidDelaySec
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_c_mid.png')) } catch { Write-LabLine ('[!] кадр c_mid: ' + $_.Exception.Message) }

# --- 5. ожидание выхода первого дочернего процесса ---------------------------
# Пока ждём, кольцевой буфер пишет кадры в shots\_ring_<Tag>.png. В
# d_first_finish копируется последний ПРОВЕРЕННЫЙ кадр, снятый при живом
# процессе; если буфера нет, серия помечается провалом (код 5) и кадр не
# подменяется снимком уже закрытого окна.

$ringLast = Join-Path $shotsDir ('_ring_' + $Tag + '.png')
$ringTmp = Join-Path $shotsDir ('_ring_' + $Tag + '.tmp.png')
$firstGone = 0
$firstGoneAt = $null
$seriesFailed = $false
$failReason = ''
$waitStart = Get-Date

$ring = Invoke-LabRingLoop -Probe {
    foreach ($cid in $childIds) {
        if (-not (Test-LabProcessAlive -ProcessId $cid)) { return [int]$cid }
    }
    if (-not (Test-LabProcessAlive -ProcessId $proc.Id)) { return -1 }
    return 0
} -Capture {
    param($FramePath)
    $null = Save-LabScreenshot -Path $FramePath -DelayMs 0
} -TmpPath $ringTmp -LastPath $ringLast -TimeoutSec $ParentTimeoutSec -PollMs 150 -OnLog {
    param($Text)
    Write-LabLine $Text
}

Write-LabLine ('[i] кольцевой буфер: кадров в буфере ' + $ring.Frames + ', сбоев ' + $ring.Failures + ', отброшено (цель уже завершилась) ' + $ring.DeadFrames + ', за ' + $ring.ElapsedSec + ' с')

if ($ring.Stopped -eq 'first') {
    $firstGone = [int]$ring.FirstGone
    $firstGoneAt = Get-Date
    Write-LabLine ''
    Write-LabLine ('[!] первым завершился дочерний процесс PID ' + $firstGone + ' в ' + $firstGoneAt.ToString('HH:mm:ss.fff') + ' (кадров в буфере: ' + $ring.Frames + ', сбоев: ' + $ring.Failures + ')')
} elseif ($ring.Stopped -eq 'probe-error') {
    Write-LabLine ('[!] опрос цели упал: ' + $ring.LastError)
} elseif ($ring.Stopped -eq 'owner') {
    Write-LabLine '[!] родительский процесс завершился раньше первого дочернего - момент выхода не зафиксирован'
} else {
    Write-LabLine ('[!] первый дочерний процесс не завершился за ' + $ParentTimeoutSec + ' с')
}

$firstShot = Join-Path $shotsDir ($Tag + '_d_first_finish.png')
if ($firstGone -le 0) {
    $failReason = 'первый дочерний процесс не зафиксирован - кадра "до выхода" быть не может'
} else {
    if ($ring.Frames -le 0) {
        $failReason = 'в кольцевом буфере нет ни одного кадра, снятого при живом процессе'
    } else {
        $failReason = Test-LabRingFrameUsable -Path $ringLast -LastFrameAt $ring.LastFrameAt -MaxStaleSec $RingMaxStaleSec
    }
}

if (-not $failReason) {
    try {
        Copy-Item -LiteralPath $ringLast -Destination $firstShot -Force -ErrorAction Stop
        if (-not (Test-LabFrameFile -Path $firstShot)) { throw 'скопированный кадр пуст' }
        Write-LabLine ('[i] ключевой кадр d_first_finish: из буфера, снят в ' + $ring.LastFrameAt.ToString('HH:mm:ss.fff') + ' (захват начат за ' + [math]::Round(((Get-Date) - $ring.LastFrameAt).TotalSeconds, 1) + ' с)')
    } catch {
        $failReason = 'не удалось сохранить кадр из буфера: ' + $_.Exception.Message
    }
}

if ($failReason) {
    $seriesFailed = $true
    if (Test-Path -LiteralPath $firstShot) { try { Remove-Item -LiteralPath $firstShot -Force } catch { } }
    $ringDiag = 'серия: ' + $Tag + "`r`n"
    $ringDiag += 'причина: ' + $failReason + "`r`n"
    $ringDiag += 'кадров в буфере: ' + $ring.Frames + ', сбоев: ' + $ring.Failures + ', отброшено: ' + $ring.DeadFrames + "`r`n"
    $ringDiag += 'останов: ' + $ring.Stopped + "`r`n"
    if ($ring.FirstGone -gt 0) { $ringDiag += 'первым завершился PID: ' + $ring.FirstGone + "`r`n" }
    if ($ring.LastFrameAt) { $ringDiag += 'начало последнего кадра буфера: ' + $ring.LastFrameAt.ToString('yyyy-MM-dd HH:mm:ss.fff') + "`r`n" }
    if ($ring.LastError) { $ringDiag += 'ошибка: ' + $ring.LastError + "`r`n" }
    $missingPath = Join-Path $shotsDir ($Tag + '_d_first_finish_MISSING.txt')
    [System.IO.File]::WriteAllText($missingPath, $ringDiag, $utf8)
    Write-LabLine ('[!] КЛЮЧЕВОЙ КАДР d_first_finish НЕ СНЯТ: ' + $failReason)
    Write-LabLine ('[!] диагностика: ' + $missingPath)
    Write-LabLine '[!] d2_after_exit и e_finish снимаются, но момент выхода не подтверждён: серия вернёт код 5'
}
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_d2_after_exit.png')) -DelayMs 120 } catch { Write-LabLine ('[!] кадр d2_after_exit: ' + $_.Exception.Message) }

# --- 6. ожидание завершения родителя ---------------------------------------

$parentTimedOut = $false
if (Test-LabProcessAlive -ProcessId $proc.Id) {
    try {
        $parentTimedOut = -not $proc.WaitForExit($ParentTimeoutSec * 1000)
    } catch {
        $parentTimedOut = $true
    }
}
$parentCode = 'нет данных'
try { $proc.Refresh(); $parentCode = [string]$proc.ExitCode } catch { }
if ($parentTimedOut) {
    Write-LabLine ('[!] родитель PID ' + $proc.Id + ' не завершился за ' + $ParentTimeoutSec + ' с - снимаю дерево')
    Stop-LabTree -ProcessId $proc.Id
}
Start-Sleep -Milliseconds 500
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_e_finish.png')) } catch { Write-LabLine ('[!] кадр e_finish: ' + $_.Exception.Message) }

# --- 7. сводка --------------------------------------------------------------

$elapsed = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
$summary = 'серия: ' + $Tag + "`r`n"
$summary += 'команда: Lab-05b.exe ' + $mask + ' ' + $P2 + ' ' + $P3 + "`r`n"
$summary += 'маска (двоично): ' + $maskText + "`r`n"
$summary += 'родитель: PID ' + $proc.Id + ', код ' + $parentCode + "`r`n"
$summary += 'дети: ' + ($childIds -join ', ') + "`r`n"
$summary += 'первым завершился: ' + $firstGone + "`r`n"
if ($firstGoneAt) { $summary += 'время: ' + $firstGoneAt.ToString('yyyy-MM-dd HH:mm:ss.fff') + "`r`n" }
$summary += 'ожидание после c_mid, с: ' + $elapsed + "`r`n"
$summary += 'кольцевой буфер: кадров ' + $ring.Frames + ', сбоев ' + $ring.Failures + ', отброшено ' + $ring.DeadFrames + "`r`n"
if ($ring.LastFrameAt) { $summary += 'начало последнего кадра буфера: ' + $ring.LastFrameAt.ToString('yyyy-MM-dd HH:mm:ss.fff') + "`r`n" }
if ($ring.LastError) { $summary += 'ошибка: ' + $ring.LastError + "`r`n" }
if ($seriesFailed) {
    $summary += 'ключевой кадр: НЕ СНЯТ - ' + $failReason + "`r`n"
} else {
    $summary += 'ключевой кадр: d_first_finish из кольцевого буфера' + "`r`n"
}
$summary += "`r`nкадры:`r`n"
foreach ($suffix in @('a_start', 'b_ps', 'c_mid', 'd_first_finish', 'd2_after_exit', 'e_finish')) {
    $shotPath = Join-Path $shotsDir ($Tag + '_' + $suffix + '.png')
    if (Test-Path -LiteralPath $shotPath) { $summary += '  ' + $shotPath + "`r`n" }
    else { $summary += '  НЕТ: ' + $shotPath + "`r`n" }
}
if (-not $seriesFailed) {
    $summary += "`r`nрасхождение итераций видно на d_first_finish (= кадр до выхода) и d2_after_exit:" + "`r`n"
    $summary += '  завершившийся процесс на d_first_finish показывает свою последнюю итерацию,' + "`r`n"
    $summary += '  выживший - текущую; разницу фиксируем в отчёте.' + "`r`n"
}

$summaryPath = Join-Path $logsDir ($Tag + '_summary.txt')
[System.IO.File]::WriteAllText($summaryPath, $summary, $utf8)
Write-LabLine ''
Write-LabText $summary

foreach ($tmp in @($ringTmp, $ringLast)) {
    if (Test-Path -LiteralPath $tmp) { try { Remove-Item -LiteralPath $tmp -Force } catch { } }
}
Write-LabLine ('[i] сводка: ' + $summaryPath)

# Скрипт работает в консоли драйвера - возвращаем её заголовок, иначе он
# останется «OS5 lab5 capture <Tag>» и попадёт в кадры следующих команд.
if ($script:OriginalTitle) {
    try { $Host.UI.RawUI.WindowTitle = $script:OriginalTitle } catch { }
}

if ($seriesFailed) {
    Write-LabLine ('[!] серия ' + $Tag + ' ПРОВАЛЕНА: ' + $failReason)
    exit 5
}
exit 0
