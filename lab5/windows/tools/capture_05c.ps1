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
    [int]$RunTimeoutSec = 240
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

# Рабочие потоки ищем по приоритету: их уровень равен P3 или P4. Если таких
# не нашлось (например .c выставил другие уровни), следим за всеми потоками.
$workerTids = @()
$procNow = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
if ($procNow) {
    foreach ($t in $procNow.Threads) {
        $lvl = ''
        try { $lvl = [string]$t.PriorityLevel } catch { }
        if ($lvl -eq $P3 -or $lvl -eq $P4) { $workerTids += [int]$t.Id }
    }
}
if ($workerTids.Count -lt 2) {
    Write-LabLine '[i] потоков с приоритетами P3/P4 не нашлось - следим за всеми TID процесса'
    $workerTids = @(Get-LabThreadIds -ProcessId $proc.Id)
}
Write-LabLine ('[i] снимок TID: ' + ($workerTids -join ', ') + ' - ждём исчезновения первого')
Write-LabLine '[i] пауза 1.2 с, чтобы текст успел попасть в консоль драйвера'
Start-Sleep -Milliseconds 1200
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_b_ps.png')) } catch { Write-LabLine ('[!] кадр b_ps: ' + $_.Exception.Message) }

Write-LabLine ('[i] промежуточный кадр через ' + $MidDelaySec + ' с')
Start-Sleep -Seconds $MidDelaySec
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_c_mid.png')) } catch { Write-LabLine ('[!] кадр c_mid: ' + $_.Exception.Message) }

# --- 4. ожидание завершения первого потока ---------------------------------
# Признак - TID из снимка пропал из списка потоков процесса. Параллельно
# кольцевой буфер кадров: последний кадр до события = кадр "момент выхода".

$ringLast = Join-Path $shotsDir ('_ring_' + $Tag + '.png')
$ringTmp = Join-Path $shotsDir ('_ring_' + $Tag + '.tmp.png')
$firstGoneTid = 0
$firstGoneAt = $null
$ringCount = 0
$waitStart = Get-Date
$deadline = $waitStart.AddSeconds($RunTimeoutSec)

while ((Get-Date) -lt $deadline) {
    $now = @(Get-LabThreadIds -ProcessId $proc.Id)
    if ($now.Count -eq 0) { break }
    foreach ($tid in $workerTids) {
        if ($now -notcontains $tid) { $firstGoneTid = $tid; break }
    }
    if ($firstGoneTid -gt 0) { break }
    if (-not (Test-LabProcessAlive -ProcessId $proc.Id)) { break }
    try {
        $null = Save-LabScreenshot -Path $ringTmp -DelayMs 0
        Move-Item -LiteralPath $ringTmp -Destination $ringLast -Force
        $ringCount++
    } catch { }
    Start-Sleep -Milliseconds 150
}

$firstShot = Join-Path $shotsDir ($Tag + '_d_first_finish.png')
if ($firstGoneTid -gt 0) {
    $firstGoneAt = Get-Date
    Write-LabLine ''
    Write-LabLine ('[!] первым завершился поток TID ' + $firstGoneTid + ' в ' + $firstGoneAt.ToString('HH:mm:ss.fff') + ' (кадров в буфере: ' + $ringCount + ')')
    Write-LabLine ('[i] остались TID: ' + ((Get-LabThreadIds -ProcessId $proc.Id) -join ', '))
    if (Test-Path -LiteralPath $ringLast) {
        try { Copy-Item -LiteralPath $ringLast -Destination $firstShot -Force } catch { Write-LabLine ('[!] копия кадра: ' + $_.Exception.Message) }
    } else {
        try { $null = Save-LabScreenshot -Path $firstShot -DelayMs 0 } catch { }
    }
} else {
    Write-LabLine '[!] завершение первого потока не зафиксировано (процесс кончился раньше или таймаут)'
    try { $null = Save-LabScreenshot -Path $firstShot -DelayMs 0 } catch { }
}
try { $null = Save-LabScreenshot -Path (Join-Path $shotsDir ($Tag + '_d2_after_exit.png')) -DelayMs 120 } catch { }

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
if ($firstGoneAt) { $summary += 'время: ' + $firstGoneAt.ToString('yyyy-MM-dd HH:mm:ss.fff') + "`r`n" }
$summary += 'ожидание после c_mid, с: ' + $elapsed + "`r`n"
$summary += "`r`nкадры:`r`n"
foreach ($suffix in @('a_start', 'b_ps', 'c_mid', 'd_first_finish', 'd2_after_exit', 'e_finish')) {
    $summary += '  ' + (Join-Path $shotsDir ($Tag + '_' + $suffix + '.png')) + "`r`n"
}
$summary += "`r`nразница итераций двух потоков видна на d_first_finish (оба потока ещё в кадре)" + "`r`n"

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
