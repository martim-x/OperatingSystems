# ============================================================================
# capture_05c.ps1 - съёмка серии для Lab-05c (два дочерних ПОТОКА)
#
#   capture_05c.ps1 -P1 <маска> -P2 <класс процесса> -P3 <поток 1> -P4 <поток 2> -Tag <метка>
#
# P1: "all" | 0x... | 0b... | десятичное число
# P2: Idle | BelowNormal | Normal | AboveNormal | High | RealTime
# P3, P4: Idle | Lowest | BelowNormal | Normal | AboveNormal | Highest | TimeCritical
#
# Потоки одного процесса всегда живут в одном консольном окне, поэтому кадры -
# это окно Lab-05c + левая половина экрана с консолью драйвера (там таблица
# потоков). "Первый завершившийся поток" определяется по исчезновению TID
# из списка потоков процесса.
# ============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$P1,
    [Parameter(Mandatory = $true)][string]$P2,
    [Parameter(Mandatory = $true)][string]$P3,
    [Parameter(Mandatory = $true)][string]$P4,
    [Parameter(Mandatory = $true)][string]$Tag,
    [string]$Root = '',
    [ValidateSet('right', 'full')][string]$Layout = 'right',
    [int]$StartDelaySec = 3,
    [int]$MidDelaySec = 10,
    [int]$RunTimeoutSec = 240,
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

$exe = Join-Path $work 'Lab-05c.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    Write-LabLine ('[!] не найден ' + $exe)
    Write-LabLine '[!] сначала соберите exe: queue\01_build.cmd (MSVC ARM64 Developer Command Prompt)'
    exit 2
}

$knownClass = @('Idle', 'BelowNormal', 'Normal', 'AboveNormal', 'High', 'RealTime')
$knownThread = @('Idle', 'Lowest', 'BelowNormal', 'Normal', 'AboveNormal', 'Highest', 'TimeCritical')
if ($knownClass -notcontains $P2) { Write-LabLine ('[!] P2=' + $P2 + ' не из списка классов процесса: ' + ($knownClass -join ', ')) }
if ($knownThread -notcontains $P3) { Write-LabLine ('[!] P3=' + $P3 + ' не из списка приоритетов потока: ' + ($knownThread -join ', ')) }
if ($knownThread -notcontains $P4) { Write-LabLine ('[!] P4=' + $P4 + ' не из списка приоритетов потока: ' + ($knownThread -join ', ')) }

$mask = ConvertTo-LabMask -Value $P1
$maskText = Format-LabMask -Mask $mask

Write-LabLine ''
Write-LabLine ('=== Lab-05c, серия ' + $Tag + ' ===')
Write-LabLine ('команда: Lab-05c.exe ' + $mask + ' ' + $P2 + ' ' + $P3 + ' ' + $P4 + '   (P1 ' + $P1 + ' -> маска ' + $maskText + ')')
Write-LabLine ('число логических процессоров: ' + (Get-LabProcessorCount))

# --- 1. запуск --------------------------------------------------------------

$proc = $null
try {
    $childArgs = @([string]$mask, $P2, $P3, $P4)
    $proc = Start-Process -FilePath $exe -ArgumentList $childArgs -WorkingDirectory $work -PassThru
} catch {
    Write-LabLine ('[!] не удалось запустить Lab-05c.exe: ' + $_.Exception.Message)
    exit 3
}
Write-LabLine ('процесс: PID ' + $proc.Id)

# --- 2. раскладка окна ------------------------------------------------------

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

if ($Layout -eq 'right') {
    $x = $area.Left + [int][math]::Floor($area.Width * 0.42)
    $w = $area.Width - [int][math]::Floor($area.Width * 0.42)
} else {
    $x = $area.Left
    $w = $area.Width
}
[void](Place-LabTarget -TargetId $proc.Id -X $x -Y $area.Top -Width $w -Height $area.Height -Hint 'Lab-05c')

# --- 3. кадры старта и таблица потоков -------------------------------------

Write-LabLine ('[i] старт серии, кадр a_start через ' + $StartDelaySec + ' с')
Start-Sleep -Seconds $StartDelaySec
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_a_start.png')) } catch { Write-LabLine ('[!] кадр a_start: ' + $_.Exception.Message) }

Show-LabProcessTable -ProcessId @($proc.Id)
$threadTitle = '(P3=' + $P3 + ', P4=' + $P4 + ')'
Show-LabThreadTable -ProcessId $proc.Id -Title $threadTitle

# Выбираем ровно два worker по приоритету и исключаем главный поток
# (обычно Normal/Wait). Не подменяем неоднозначный выбор списком всех TID.
$workerSelection = [pscustomobject]@{ ThreadIds = @(); Error = 'процесс завершился до выбора рабочих TID' }
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    $procNow = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if (-not $procNow) { break }
    $workerSelection = Select-LabWorkerThreadIds -Threads @($procNow.Threads) -P3 $P3 -P4 $P4
    if ($workerSelection.ThreadIds.Count -eq 2 -and -not $workerSelection.Error) { break }
    Start-Sleep -Milliseconds 100
}
$workerTids = @($workerSelection.ThreadIds)
if ($workerSelection.Error) {
    Write-LabLine ('[!] невозможно однозначно выбрать два рабочих TID: ' + $workerSelection.Error)
} else {
    Write-LabLine ('[i] выбраны рабочие TID: ' + ($workerTids -join ', ') + ' - ждём исчезновения одного из них')
}
Write-LabLine '[i] пауза 1.2 с, чтобы текст успел попасть в консоль драйвера'
Start-Sleep -Milliseconds 1200
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_b_ps.png')) } catch { Write-LabLine ('[!] кадр b_ps: ' + $_.Exception.Message) }

Write-LabLine ('[i] промежуточный кадр через ' + $MidDelaySec + ' с')
Start-Sleep -Seconds $MidDelaySec
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_c_mid.png')) } catch { Write-LabLine ('[!] кадр c_mid: ' + $_.Exception.Message) }

# --- 4. ожидание завершения первого потока ---------------------------------
# Признак - TID из снимка пропал из списка потоков процесса. Параллельно
# кольцевой буфер кадров: последний ПРОВЕРЕННЫЙ кадр при живом процессе и есть
# кадр "момент выхода". Пустой буфер - провал серии (код 5), а не подмена кадра
# снимком уже завершившегося процесса.

$ringLast = Join-Path $shotsDir ('_ring_' + $Tag + '.png')
$ringTmp = Join-Path $shotsDir ('_ring_' + $Tag + '.tmp.png')
$firstGoneTid = 0
$remainingWorkerTids = @()
$firstGoneAt = $null
$seriesFailed = $false
$failReason = ''
$waitStart = Get-Date

if ($workerSelection.Error) {
    $ring = [pscustomobject]@{ Frames = 0; Failures = 0; DeadFrames = 0; LastFrameAt = $null; LastError = $workerSelection.Error; Stopped = 'selection-error'; FirstGone = 0; RemainingTids = @(); ElapsedSec = 0 }
    foreach ($stale in @($ringTmp, $ringLast)) { if (Test-Path -LiteralPath $stale) { Remove-Item -LiteralPath $stale -Force -ErrorAction SilentlyContinue } }
} else {
    $ring = Invoke-LabRingLoop -Probe {
        $now = @(Get-LabThreadIds -ProcessId $proc.Id)
        if ($now.Count -eq 0) { return -2 }
        $snapshot = Get-LabWorkerExitSnapshot -WorkerTids $workerTids -CurrentTids $now
        if ($snapshot.Status -eq 'first') {
            return [pscustomobject]@{ Code = 1; FirstGone = $snapshot.FirstGone; RemainingTids = @($snapshot.RemainingTids) }
        }
        if ($snapshot.Status -eq 'ambiguous') {
            return [pscustomobject]@{ Code = -2; FirstGone = 0; RemainingTids = @($snapshot.RemainingTids) }
        }
        return [pscustomobject]@{ Code = 0; FirstGone = 0; RemainingTids = @($snapshot.RemainingTids) }
    } -Capture {
        param($FramePath)
        $null = Save-LabScreenshot -Path $FramePath -DelayMs 0
    } -TmpPath $ringTmp -LastPath $ringLast -TimeoutSec $RunTimeoutSec -PollMs 150 -OnLog {
        param($Text)
        Write-LabLine $Text
    }
}

Write-LabLine ('[i] кольцевой буфер: кадров в буфере ' + $ring.Frames + ', сбоев ' + $ring.Failures + ', отброшено (процесс уже завершился) ' + $ring.DeadFrames + ', за ' + $ring.ElapsedSec + ' с')

if ($ring.Stopped -eq 'first') {
    $firstGoneTid = [int]$ring.FirstGone
    $remainingWorkerTids = @($ring.RemainingTids)
    $firstGoneAt = Get-Date
    Write-LabLine ''
    Write-LabLine ('[!] первым завершился поток TID ' + $firstGoneTid + ' в ' + $firstGoneAt.ToString('HH:mm:ss.fff') + ' (кадров в буфере: ' + $ring.Frames + ', сбоев: ' + $ring.Failures + ')')
    Write-LabLine ('[i] остались worker TID: ' + ($remainingWorkerTids -join ', '))
} elseif ($ring.Stopped -eq 'probe-error') {
    Write-LabLine ('[!] опрос цели упал: ' + $ring.LastError)
} elseif ($ring.Stopped -eq 'ambiguous') {
    Write-LabLine ('[!] несколько worker исчезли между опросами; первый TID неоднозначен, оставшиеся: ' + ($ring.RemainingTids -join ', '))
} elseif ($ring.Stopped -eq 'selection-error') {
    Write-LabLine ('[!] наблюдение не начато: ' + $ring.LastError)
} elseif ($ring.Stopped -eq 'timeout') {
    Write-LabLine ('[!] первый рабочий поток не завершился за ' + $RunTimeoutSec + ' с')
} elseif ($ring.Stopped -eq 'owner') {
    Write-LabLine '[!] процесс завершился раньше, чем пропал отдельный поток - момент выхода потока не зафиксирован'
} else {
    Write-LabLine ('[!] останов ожидания: ' + $ring.Stopped)
}

$firstShot = Join-Path $shotsDir ($Tag + '_d_first_finish.png')
if ($firstGoneTid -le 0) {
    if ($workerSelection.Error) { $failReason = $workerSelection.Error }
    elseif ($ring.Stopped -eq 'ambiguous') { $failReason = 'между опросами завершились несколько рабочих потоков - первый TID неоднозначен' }
    else { $failReason = 'завершение первого потока не зафиксировано - кадра "до выхода" быть не может' }
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
    if ($ring.FirstGone -gt 0) { $ringDiag += 'первым завершился TID: ' + $ring.FirstGone + "`r`n" }
    if ($remainingWorkerTids.Count -gt 0) { $ringDiag += 'оставшийся worker TID на том же опросе: ' + ($remainingWorkerTids -join ', ') + "`r`n" }
    if ($ring.LastFrameAt) { $ringDiag += 'начало последнего кадра буфера: ' + $ring.LastFrameAt.ToString('yyyy-MM-dd HH:mm:ss.fff') + "`r`n" }
    if ($ring.LastError) { $ringDiag += 'ошибка: ' + $ring.LastError + "`r`n" }
    $missingPath = Join-Path $shotsDir ($Tag + '_d_first_finish_MISSING.txt')
    [System.IO.File]::WriteAllText($missingPath, $ringDiag, $utf8)
    Write-LabLine ('[!] КЛЮЧЕВОЙ КАДР d_first_finish НЕ СНЯТ: ' + $failReason)
    Write-LabLine ('[!] диагностика: ' + $missingPath)
    Write-LabLine '[!] d2_after_exit и e_finish снимаются, но момент выхода не подтверждён: серия вернёт код 5'
}
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_d2_after_exit.png')) -DelayMs 120 } catch { Write-LabLine ('[!] кадр d2_after_exit: ' + $_.Exception.Message) }

# --- 5. ожидание завершения процесса ---------------------------------------

$timedOut = $false
if (Test-LabProcessAlive -ProcessId $proc.Id) {
    try {
        $timedOut = -not $proc.WaitForExit($RunTimeoutSec * 1000)
    } catch {
        $timedOut = $true
    }
}
$exitCodeText = 'нет данных'
try { $proc.Refresh(); $exitCodeText = [string]$proc.ExitCode } catch { }
if ($timedOut) {
    Write-LabLine ('[!] процесс PID ' + $proc.Id + ' не завершился за ' + $RunTimeoutSec + ' с - снимаю дерево')
    Stop-LabTree -ProcessId $proc.Id
}
Start-Sleep -Milliseconds 500
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_e_finish.png')) } catch { Write-LabLine ('[!] кадр e_finish: ' + $_.Exception.Message) }

# --- 6. сводка --------------------------------------------------------------

$elapsed = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
$summary = 'серия: ' + $Tag + "`r`n"
$summary += 'команда: Lab-05c.exe ' + $mask + ' ' + $P2 + ' ' + $P3 + ' ' + $P4 + "`r`n"
$summary += 'маска (двоично): ' + $maskText + "`r`n"
$summary += 'процесс: PID ' + $proc.Id + ', код ' + $exitCodeText + "`r`n"
$summary += 'TID на момент b_ps: ' + ($workerTids -join ', ') + "`r`n"
$summary += 'первым завершился TID: ' + $firstGoneTid + "`r`n"
if ($remainingWorkerTids.Count -gt 0) { $summary += 'оставшийся worker TID на том же опросе: ' + ($remainingWorkerTids -join ', ') + "`r`n" }
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
    $summary += "`r`nразница итераций двух потоков видна на d_first_finish (оба потока ещё в кадре)" + "`r`n"
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
