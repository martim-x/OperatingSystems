# ============================================================================
# start_driver.ps1 - запуск драйвера очереди в НОВОМ консольном окне
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File start_driver.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File start_driver.ps1 -ExitWhenIdle
#   powershell -NoProfile -ExecutionPolicy Bypass -File start_driver.ps1 -Clean
#
# Очистка результатов прошлых прогонов - ЯВНАЯ: по умолчанию done\, shots\,
# logs\ не трогаются (кадры и сводки предыдущей серии - это сдаваемые данные,
# а не мусор). -Clean удаляет их содержимое, -IncludeQueue вместе с -Clean
# дополнительно удаляет queue\*.cmd (восстановление: git checkout -- ...queue).
#
# Каталог queue\ НЕ удаляется никогда: это список команд библиотеки.
# ============================================================================

[CmdletBinding()]
param(
    [string]$Root = '',
    [switch]$Clean,
    [switch]$IncludeQueue,
    [switch]$ExitWhenIdle,
    [int]$TimeoutSec = 600
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lab_common.ps1')
Initialize-LabNative

$work = Resolve-LabRoot -Requested $Root -Fallback $PSScriptRoot
$queueDir = Join-Path $work 'queue'
$driver = Join-Path $work 'run_lab.ps1'

if (-not (Test-Path -LiteralPath $driver)) {
    Write-Host ('[!] не найден ' + $driver + ' - положите start_driver.ps1 рядом с run_lab.ps1')
    exit 2
}

# --- очистка результатов прошлых прогонов (только по -Clean) -----------------

if ($Clean) {
    if ($IncludeQueue) {
        $cleared = @(Clear-LabResults -Work $work -IncludeQueue)
    } else {
        $cleared = @(Clear-LabResults -Work $work)
    }
    foreach ($dir in $cleared) {
        Write-Host ('[.] очищено: ' + $dir)
    }
    if ($IncludeQueue) {
        Write-Host ('[.] очищена очередь: ' + (Join-Path $work 'queue') + ' (восстановить: git checkout -- lab5/windows/tools/queue)')
    }
} else {
    $existing = 0
    foreach ($sub in @('done', 'shots', 'logs')) {
        $dir = Join-Path $work $sub
        if (Test-Path -LiteralPath $dir) {
            $existing += @(Get-ChildItem -LiteralPath $dir -Force -File -ErrorAction SilentlyContinue).Count
        }
    }
    if ($existing -gt 0) {
        Write-Host ('[i] в done\shots\logs уже есть ' + $existing + ' файлов - они НЕ удаляются')
        Write-Host '[i] смешать новые кадры со старыми: очистить перед прогоном - start_driver.ps1 -Clean'
        Write-Host('[i] либо разложить результаты по каталогам: ' + (Join-Path $work 'shots') + ', ' + (Join-Path $work 'done'))
    }
}

# --- проверки перед стартом ------------------------------------------------

$cmds = @(Get-ChildItem -LiteralPath $queueDir -Filter '*.cmd' -ErrorAction SilentlyContinue | Sort-Object Name)
Write-Host ('[i] рабочий каталог: ' + $work)
Write-Host ('[i] команд в очереди: ' + $cmds.Count)
if ($cmds.Count -eq 0) {
    Write-Host '[!] очередь пуста: драйвер будет ждать появления *.cmd в queue\'
}
if (-not (Test-Path -LiteralPath (Join-Path $work 'Lab-05b.exe'))) {
    Write-Host '[i] exe ещё не собраны - начните с queue\01_build.cmd'
}

# Исходники окна сборки: build.cmd ищет их рядом с собой и в src\.
$srcRoot = Split-Path -Parent $work
$missingSrc = @()
foreach ($n in @('Lab-05a', 'Lab-05x', 'Lab-05b', 'Lab-05c')) {
    $found = $false
    foreach ($cand in @(($n + '.c'), (($n -replace '-', '_') + '.c'))) {
        if (Test-Path -LiteralPath (Join-Path $srcRoot $cand)) { $found = $true; break }
        if (Test-Path -LiteralPath (Join-Path (Join-Path $srcRoot 'src') $cand)) { $found = $true; break }
    }
    if (-not $found) { $missingSrc += $n }
}
if ($missingSrc.Count -gt 0) {
    Write-Host ('[!] нет исходников для сборки: ' + ($missingSrc -join ', ') + ' (искал: ' + $srcRoot + ' и ' + (Join-Path $srcRoot 'src') + ')')
    Write-Host '[!] 01_build.cmd упадёт: исходники lab5\linux - POSIX (pthreads/sched.h), MSVC их не собирает'
}

# --- запуск отдельным консольным окном -------------------------------------

$psExe = ''
if ($env:SystemRoot) { $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
if (-not $psExe) { $psExe = 'powershell.exe' }
if (-not (Test-Path -LiteralPath $psExe)) { $psExe = 'powershell.exe' }

$argLine = '-NoProfile -ExecutionPolicy Bypass -File "' + $driver + '" -Root "' + $work + '" -TimeoutSec ' + $TimeoutSec
if (-not $ExitWhenIdle) { $argLine += ' -KeepAlive' }

Write-Host ('[i] запуск: powershell ' + $argLine)

try {
    $proc = Start-Process -FilePath $psExe -ArgumentList $argLine -WorkingDirectory $work -PassThru -WindowStyle Normal
} catch {
    Write-Host ('[!] не удалось запустить драйвер: ' + $_.Exception.Message)
    exit 3
}

Start-Sleep -Seconds 3

$alive = $true
try {
    $proc.Refresh()
    $alive = -not $proc.HasExited
} catch {
    $alive = [bool](Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)
}

if (-not $alive) {
    Write-Host ('[!] драйвер завершился сразу, код ' + $proc.ExitCode)
    Write-Host '[!] типичные причины: политика ExecutionPolicy, отсутствует run_lab.ps1, синтаксическая ошибка в скрипте'
    Write-Host ('[i] проверьте вручную: powershell -NoProfile -ExecutionPolicy Bypass -File "' + $driver + '"')
    exit 4
}

Write-Host ('[OK] драйвер работает, PID ' + $proc.Id + ', окно слева на экране')
Write-Host '[i] дальше: драйвер сам разбирает queue\*.cmd по порядку имён'
Write-Host ('[i] кадры: ' + (Join-Path $work 'shots') + '   тексты: ' + (Join-Path $work 'done'))
