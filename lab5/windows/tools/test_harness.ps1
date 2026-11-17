# ============================================================================
# test_harness.ps1 - offline-проверки харнесса ЛР5 (без Windows)
#
# Запуск (macOS/Linux с pwsh, или Windows PowerShell 5.1):
#   pwsh -NoProfile -File .\test_harness.ps1
#
# Что проверяется:
#   1) парсинг всех .ps1 (Parser::ParseFile) и кодировки файлов;
#   2) относительные пути внутри queue\*.cmd;
#   3) helper-функции lab_common.ps1 (маска, номер команды, корень, очистка);
#   4) непротиворечивость таймаутов: драйвер не убивает серию раньше, чем
#      capture_05b/05c успевают закончить сами;
#   5) smoke-прогон run_lab.ps1 -NoScreenshot на копии каталога (только там,
#      где есть sh: cmd.exe эмулируется шимом, реальные exe не нужны);
#   6) кольцевой буфер кадров: целостность PNG, отказ от кадра после выхода,
#      stale _ring_*.tmp.png, сбой опроса цели, явный провал при пустом буфере,
#      код 5 в capture_05b/05c и его пометка драйвером (run_lab).
#
# Скрипт ничего не пишет в репозиторий: все прогоны идут в отдельном temp.
# ============================================================================

[CmdletBinding()]
param(
    [string]$KeepTemp = ''
)

$ErrorActionPreference = 'Stop'

$script:Pass = 0
$script:Fail = 0
$script:Skip = 0
$script:Tools = $PSScriptRoot
$script:WindowsDir = Split-Path -Parent $PSScriptRoot
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)

function Assert-True {
    param([bool]$Condition, [string]$Name, [string]$Detail = '')
    if ($Condition) {
        $script:Pass++
        Write-Host ('  [ok]   ' + $Name)
    } else {
        $script:Fail++
        Write-Host ('  [FAIL] ' + $Name + $(if ($Detail) { ' -- ' + $Detail } else { '' }))
    }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Name, [string]$Detail = '')
    $detail = 'получено "' + $Actual + '", ожидалось "' + $Expected + '"'
    if ($Detail) { $detail += ' (' + $Detail + ')' }
    Assert-True -Condition ([string]$Actual -eq [string]$Expected) -Name $Name -Detail $detail
}

function Skip-Test {
    param([string]$Name, [string]$Why)
    $script:Skip++
    Write-Host ('  [skip] ' + $Name + ' -- ' + $Why)
}

function New-TestDir {
    param([string]$Name = 'lab5test')
    $base = $null
    if ($env:TMPDIR) { $base = $env:TMPDIR }
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    $dir = Join-Path $base ($Name + '_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $dir -Force
    return $dir
}

function Write-TextFile {
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    [System.IO.File]::WriteAllText($Path, $Text, $script:Utf8)
}

Write-Host '=== 1. Парсинг и кодировки ==='

$ps1Files = @(Get-ChildItem -LiteralPath $script:Tools -Filter '*.ps1' | Sort-Object Name)
Assert-True -Condition ($ps1Files.Count -ge 5) -Name ('найдено .ps1: ' + $ps1Files.Count + ' (ожидалось >= 5)')

foreach ($f in $ps1Files) {
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
    $errText = ''
    if ($errors -and $errors.Count -gt 0) { $errText = ($errors | ForEach-Object { $_.Message }) -join '; ' }
    Assert-True -Condition (($errors -and $errors.Count -gt 0) -eq $false) -Name ('парсер: ' + $f.Name) -Detail $errText
}

foreach ($f in $ps1Files) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    Assert-True -Condition $bom -Name ('UTF-8 BOM: ' + $f.Name)
}

$cmdFiles = @()
$cmdFiles += Get-ChildItem -LiteralPath $script:WindowsDir -Filter '*.cmd'
$cmdFiles += Get-ChildItem -LiteralPath (Join-Path $script:Tools 'queue') -Filter '*.cmd'
foreach ($f in $cmdFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    Assert-True -Condition (-not $bom) -Name ('без BOM (cmd.exe): ' + $f.Name)
}

Write-Host ''
Write-Host '=== 2. Относительные пути в queue/*.cmd ==='

$queueDir = Join-Path $script:Tools 'queue'
$queueFiles = @(Get-ChildItem -LiteralPath $queueDir -Filter '*.cmd' | Sort-Object Name)
Assert-True -Condition ($queueFiles.Count -ge 9) -Name ('команд в очереди: ' + $queueFiles.Count + ' (ожидалось >= 9)')

$exeRefs = New-Object System.Collections.ArrayList
foreach ($f in $queueFiles) {
    $text = [System.IO.File]::ReadAllText($f.FullName, $script:Utf8)
    $matches = [regex]::Matches($text, '%~dp0((?:\.\.[\\/])+[^"\r\n]*)')
    $checked = 0
    foreach ($m in $matches) {
        $rel = $m.Groups[1].Value
        $target = Join-Path $f.DirectoryName ($rel -replace '/', '\')
        $target = [System.IO.Path]::GetFullPath($target)
        if ($target -match '\.exe$') {
            [void]$exeRefs.Add($target)
            $checked++
            continue
        }
        $checked++
        Assert-True -Condition (Test-Path -LiteralPath $target) -Name ($f.Name + ' -> ' + $rel) -Detail ('нет файла: ' + $target)
    }
    Assert-True -Condition ($checked -ge 1) -Name ($f.Name + ': найден путь через %~dp0')
}

$badExe = @($exeRefs | Where-Object { (Split-Path -Leaf $_) -notmatch '^Lab-05[a-z]\.exe$' })
$exeNames = (@($exeRefs | ForEach-Object { Split-Path -Leaf $_ } | Sort-Object -Unique) -join ', ')
Assert-Equal -Actual $badExe.Count -Expected 0 -Name ('имена exe в очереди (' + $exeNames + ')') -Detail ($badExe -join ', ')

Write-Host ''
Write-Host '=== 3. Helper-функции lab_common.ps1 ==='

. (Join-Path $script:Tools 'lab_common.ps1')

Assert-Equal -Actual (Get-LabQueueNumber -Name '01_build.cmd') -Expected '01' -Name 'Get-LabQueueNumber 01_build.cmd'
Assert-Equal -Actual (Get-LabQueueNumber -Name '07_c_s1.cmd') -Expected '07' -Name 'Get-LabQueueNumber 07_c_s1.cmd'

Assert-Equal -Actual (Format-LabMask -Mask 255 -Width 8) -Expected '11111111' -Name 'Format-LabMask 255/8'
Assert-Equal -Actual (Format-LabMask -Mask 1 -Width 8) -Expected '00000001' -Name 'Format-LabMask 1/8'
Assert-Equal -Actual (Format-LabMask -Mask 0 -Width 4) -Expected '0000' -Name 'Format-LabMask 0/4'

Assert-Equal -Actual (ConvertTo-LabMask -Value '7') -Expected 7 -Name 'ConvertTo-LabMask "7"'
Assert-Equal -Actual (ConvertTo-LabMask -Value '0x1f') -Expected 31 -Name 'ConvertTo-LabMask "0x1f"'
Assert-Equal -Actual (ConvertTo-LabMask -Value '0b101') -Expected 5 -Name 'ConvertTo-LabMask "0b101"'
$ncpu = Get-LabProcessorCount
$allMask = ConvertTo-LabMask -Value 'all'
$expectAll = [int64]([math]::Pow(2, $ncpu) - 1)
if ($ncpu -ge 63) { $expectAll = [int64]-1 }
Assert-Equal -Actual $allMask -Expected $expectAll -Name ('ConvertTo-LabMask "all" при ' + $ncpu + ' CPU')

$rootTmp = New-TestDir 'lab5root'
$null = New-Item -ItemType Directory -Path (Join-Path $rootTmp 'queue') -Force
Assert-Equal -Actual (Resolve-LabRoot -Requested $rootTmp) -Expected ([System.IO.Path]::GetFullPath($rootTmp)) -Name 'Resolve-LabRoot: каталог с queue'
$threw = $false
try { $null = Resolve-LabRoot -Requested (Join-Path $rootTmp 'nope') } catch { $threw = $true }
Assert-True -Condition $threw -Name 'Resolve-LabRoot: без queue бросает ошибку'

Assert-True -Condition ([bool](Get-Command -Name Clear-LabResults -ErrorAction SilentlyContinue)) -Name 'Clear-LabResults существует в lab_common.ps1'

Write-Host ''
Write-Host '=== 3c. Process Explorer: центр строки процесса ==='

$peRowYCommand = Get-Command -Name Get-LabPeRowClickY -ErrorAction SilentlyContinue
Assert-True -Condition ([bool]$peRowYCommand) -Name 'Get-LabPeRowClickY определена'
if ($peRowYCommand) {
    Assert-Equal -Actual (Get-LabPeRowClickY -Row 1) -Expected 35 -Name 'Process Explorer: первая строка кликается по центру'
    Assert-Equal -Actual (Get-LabPeRowClickY -Row 2) -Expected 54 -Name 'Process Explorer: вторая строка имеет шаг 19 px'
    $badPeRow = $false
    try { $null = Get-LabPeRowClickY -Row 0 } catch { $badPeRow = $true }
    Assert-True -Condition $badPeRow -Name 'Process Explorer: нулевой номер строки запрещён'
}

Write-Host ''
Write-Host '=== 3b. Выбор рабочих TID без главного потока ==='

$selectWorkerCommand = Get-Command -Name Select-LabWorkerThreadIds -ErrorAction SilentlyContinue
Assert-True -Condition ([bool]$selectWorkerCommand) -Name 'Select-LabWorkerThreadIds определена'
$exitSnapshotCommand = Get-Command -Name Get-LabWorkerExitSnapshot -ErrorAction SilentlyContinue
Assert-True -Condition ([bool]$exitSnapshotCommand) -Name 'Get-LabWorkerExitSnapshot определена'

if ($selectWorkerCommand -and $exitSnapshotCommand) {
    $normalThreads = @(
        [pscustomobject]@{ Id = 111; PriorityLevel = 'Normal'; ThreadState = 'Wait' },
        [pscustomobject]@{ Id = 222; PriorityLevel = 'Normal'; ThreadState = 'Running' },
        [pscustomobject]@{ Id = 333; PriorityLevel = 'Normal'; ThreadState = 'Ready' }
    )
    $normalSelection = Select-LabWorkerThreadIds -Threads $normalThreads -P3 'Normal' -P4 'Normal'
    Assert-Equal -Actual ($normalSelection.ThreadIds -join ',') -Expected '222,333' -Name 'Lab-05c c1: из трёх Normal TID выбираются два рабочих, главный Wait исключён'
    Assert-Equal -Actual $normalSelection.Error -Expected '' -Name 'Lab-05c c1: выбор двух рабочих TID однозначен'

    $unequalThreads = @(
        [pscustomobject]@{ Id = 444; PriorityLevel = 'Normal'; ThreadState = 'Wait' },
        [pscustomobject]@{ Id = 555; PriorityLevel = 'Lowest'; ThreadState = 'Ready' },
        [pscustomobject]@{ Id = 666; PriorityLevel = 'Highest'; ThreadState = 'Running' }
    )
    $unequalSelection = Select-LabWorkerThreadIds -Threads $unequalThreads -P3 'Lowest' -P4 'Highest'
    Assert-Equal -Actual ($unequalSelection.ThreadIds -join ',') -Expected '555,666' -Name 'Lab-05c c2/c3: рабочие TID выбираются по P3/P4'

    $ambiguousThreads = @(
        [pscustomobject]@{ Id = 777; PriorityLevel = 'Normal'; ThreadState = 'Running' },
        [pscustomobject]@{ Id = 888; PriorityLevel = 'Normal'; ThreadState = 'Ready' },
        [pscustomobject]@{ Id = 999; PriorityLevel = 'Normal'; ThreadState = 'Running' }
    )
    $ambiguousSelection = Select-LabWorkerThreadIds -Threads $ambiguousThreads -P3 'Normal' -P4 'Normal'
    Assert-Equal -Actual $ambiguousSelection.ThreadIds.Count -Expected 0 -Name 'Lab-05c: неоднозначный набор не превращается в список всех TID'
    Assert-True -Condition ([bool]$ambiguousSelection.Error) -Name 'Lab-05c: неоднозначный выбор возвращает причину провала'

    $exitSnapshot = Get-LabWorkerExitSnapshot -WorkerTids @(222, 333) -CurrentTids @(111, 333)
    Assert-Equal -Actual ($exitSnapshot.ExitedTids -join ',') -Expected '222' -Name 'Lab-05c: snapshot определяет ровно один исчезнувший worker'
    Assert-Equal -Actual ($exitSnapshot.RemainingTids -join ',') -Expected '333' -Name 'Lab-05c: snapshot сохраняет живой worker из того же опроса'
    $bothGoneSnapshot = Get-LabWorkerExitSnapshot -WorkerTids @(222, 333) -CurrentTids @(111)
    Assert-Equal -Actual $bothGoneSnapshot.ExitedTids.Count -Expected 2 -Name 'Lab-05c: одновременное исчезновение двух workers распознаётся как неоднозначное'
}

if (Get-Command -Name Clear-LabResults -ErrorAction SilentlyContinue) {
    $w = New-TestDir 'lab5clean'
    Write-TextFile -Path (Join-Path $w 'queue\01_x.cmd') -Text 'echo x'
    Write-TextFile -Path (Join-Path $w 'done\01.txt') -Text 'log'
    Write-TextFile -Path (Join-Path $w 'shots\05b_s1_a_start.png') -Text 'png'
    Write-TextFile -Path (Join-Path $w 'logs\05b_s1_summary.txt') -Text 'sum'

    $null = Clear-LabResults -Work $w
    $left = @(Get-ChildItem -LiteralPath $w -Recurse -File | ForEach-Object { $_.FullName.Substring($w.Length + 1) })
    Assert-True -Condition ($left.Count -eq 1 -and $left[0] -match '01_x\.cmd$') -Name 'Clear-LabResults без -IncludeQueue: чистит результаты, очередь цела' -Detail ($left -join ', ')

    $null = Clear-LabResults -Work $w -IncludeQueue
    $left = @(Get-ChildItem -LiteralPath $w -Recurse -File)
    Assert-Equal -Actual $left.Count -Expected 0 -Name 'Clear-LabResults -IncludeQueue: каталог пуст'
}

Write-Host ''
Write-Host '=== 4. Таймауты: драйвер длиннее серии ==='

function Get-ParamDefault {
    param([string]$Path, [string]$Name)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    $paramAst = $ast.ParamBlock
    if (-not $paramAst) { return $null }
    foreach ($p in $paramAst.Parameters) {
        if ($p.Name.VariablePath.UserPath -ne $Name) { continue }
        if (-not $p.DefaultValue) { return $null }
        $text = $p.DefaultValue.Extent.Text
        $value = 0
        if ([int]::TryParse($text, [ref]$value)) { return $value }
        return $text
    }
    return $null
}

$runLabPath = Join-Path $script:Tools 'run_lab.ps1'
$driverTimeout = Get-ParamDefault -Path $runLabPath -Name 'TimeoutSec'
Assert-True -Condition ($driverTimeout -is [int] -and $driverTimeout -gt 0) -Name ('run_lab TimeoutSec по умолчанию: ' + $driverTimeout)

foreach ($pair in @(@('capture_05b.ps1', 'ParentTimeoutSec'), @('capture_05c.ps1', 'RunTimeoutSec'))) {
    $capPath = Join-Path $script:Tools $pair[0]
    $capTimeout = Get-ParamDefault -Path $capPath -Name $pair[1]
    $startDelay = Get-ParamDefault -Path $capPath -Name 'StartDelaySec'
    $midDelay = Get-ParamDefault -Path $capPath -Name 'MidDelaySec'
    Assert-True -Condition ($capTimeout -is [int] -and $capTimeout -gt 0) -Name ($pair[0] + ' ' + $pair[1] + ' по умолчанию: ' + $capTimeout)
    if ($capTimeout -is [int] -and $driverTimeout -is [int]) {
        $worst = $capTimeout + $capTimeout + $startDelay + $midDelay + 60
        Assert-True -Condition ($driverTimeout -ge $worst) -Name ($pair[0] + ': драйвер (' + $driverTimeout + ' с) не короче худшего случая серии (' + $worst + ' с)')
    }
}

Write-Host ''
Write-Host '=== 5. start_driver: очистка по умолчанию не разрушает кадры ==='

$sdText = [System.IO.File]::ReadAllText((Join-Path $script:Tools 'start_driver.ps1'), $script:Utf8)
Assert-True -Condition ($sdText -match '\[switch\]\$Clean\b') -Name 'start_driver принимает -Clean (явная очистка)'
Assert-True -Condition ($sdText -notmatch '\[switch\]\$NoClean\b') -Name 'start_driver не требует -NoClean (очистка не по умолчанию)'

Write-Host ''
Write-Host '=== 6. build.cmd: контракт сборки ==='

$buildPath = Join-Path $script:WindowsDir 'build.cmd'
$buildText = [System.IO.File]::ReadAllText($buildPath, $script:Utf8)
Assert-True -Condition ($buildText -match 'BUILD FAILED: не найдено ни одного исходника') -Name 'build.cmd падает, если нет ни одного .c'
Assert-True -Condition ($buildText -match 'call "%VCVARS%" %LAB5_ARCH%') -Name 'build.cmd вызывает vcvarsall с выбранной архитектурой'
Assert-True -Condition ($buildText -match 'LAB5_ARCH=arm64' -and $buildText -match 'LAB5_ARCH=x64') -Name 'build.cmd выбирает архитектуру по хосту (arm64/x64)'
Assert-True -Condition ($buildText -match 'src\\') -Name 'build.cmd ищет исходники и в src\'

$srcCandidates = @(Get-ChildItem -LiteralPath $script:WindowsDir -Filter '*.c' -ErrorAction SilentlyContinue)
Write-Host ('  [i] исходников .c в ' + $script:WindowsDir + ': ' + $srcCandidates.Count)

Write-Host ''
Write-Host '=== 7. Smoke-прогон run_lab.ps1 -NoScreenshot ==='

$onWindows = ($env:OS -eq 'Windows_NT')
$shPath = $null
if (-not $onWindows) {
    $shCmd = Get-Command -Name sh -ErrorAction SilentlyContinue
    if ($shCmd) { $shPath = $shCmd.Source }
}

if (-not $shPath) {
    Skip-Test -Name 'smoke run_lab' -Why 'нужен sh и эмуляция cmd.exe (на Windows прогоняйте очередь вживую)'
} else {
    $smoke = New-TestDir 'lab5smoke'
    $smokeTools = Join-Path $smoke 'tools'
    $smokeQueue = Join-Path $smokeTools 'queue'
    $shimDir = Join-Path $smoke 'shim'
    $null = New-Item -ItemType Directory -Path $smokeTools, $smokeQueue, $shimDir -Force

    Copy-Item -LiteralPath (Join-Path $script:Tools 'run_lab.ps1') -Destination $smokeTools
    Copy-Item -LiteralPath (Join-Path $script:Tools 'lab_common.ps1') -Destination $smokeTools

    # Шим cmd.exe: повторяет ровно тот контракт, который использует драйвер, -
    # обёртка done\_NN.run.cmd с перенаправлением вывода в done\_NN.out.tmp.
    $shim = @'
#!/bin/sh
wrapper=""
for a in "$@"; do
  case "$a" in
    *.run.cmd) wrapper="$a" ;;
  esac
done
[ -z "$wrapper" ] && exit 127
dir=$(dirname "$wrapper")
nn=$(basename "$wrapper" | sed 's/^_//; s/\.run\.cmd$//')
work=$(dirname "$dir")
src=$(ls "$work"/queue/"$nn"_*.cmd 2>/dev/null | head -n 1)
[ -z "$src" ] && exit 127
sh "$src" > "$dir/_$nn.out.tmp" 2>&1
exit $?
'@
    Write-TextFile -Path (Join-Path $shimDir 'cmd.exe') -Text ($shim -replace "`r`n", "`n")
    & chmod +x (Join-Path $shimDir 'cmd.exe')

    $queueBodies = @{
        '01_first.cmd' = "#!/bin/sh`nprintf 'первая команда\nвторая строка\n'`nexit 0`n"
        '02_fail.cmd'  = "#!/bin/sh`nprintf 'команда с кодом 7\n'`nexit 7`n"
        '03_tail.cmd'  = "#!/bin/sh`nprintf 'хвост без перевода строки'`nexit 0`n"
        '04_slow.cmd'  = "#!/bin/sh`nsleep 20`nprintf 'не должно дойти\n'`nexit 0`n"
        '05_five.cmd'  = "#!/bin/sh`nprintf 'серия без ключевого кадра\n'`nexit 5`n"
    }
    foreach ($qName in $queueBodies.Keys) {
        Write-TextFile -Path (Join-Path $smokeQueue $qName) -Text $queueBodies[$qName]
    }

    $savedPath = $env:PATH
    $env:PATH = $shimDir + [System.IO.Path]::PathSeparator + $env:PATH
    $savedConsole = $null
    try {
        $output = & (Join-Path $smokeTools 'run_lab.ps1') -Root $smokeTools -NoScreenshot -TimeoutSec 5 -IdleExitSec 2 2>&1
        $output = @($output | ForEach-Object { [string]$_ })
    } finally {
        $env:PATH = $savedPath
    }

    $done = Join-Path $smokeTools 'done'
    $shots = Join-Path $smokeTools 'shots'

    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $done '01.txt')) -Name 'smoke: done\01.txt создан'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $done '01.done')) -Name 'smoke: done\01.done создан'

    if (Test-Path -LiteralPath (Join-Path $done '01.txt')) {
        $t1 = [System.IO.File]::ReadAllText((Join-Path $done '01.txt'), $script:Utf8)
        Assert-True -Condition ($t1 -match 'код возврата: 0') -Name 'smoke: код возврата 0 записан'
        Assert-True -Condition ($t1 -match 'первая команда') -Name 'smoke: вывод команды попал в лог'
        Assert-True -Condition ($t1 -match 'команда: cmd /c queue\\01_first\.cmd') -Name 'smoke: в логе есть строка команды'
    }

    if (Test-Path -LiteralPath (Join-Path $done '02.txt')) {
        $t2 = [System.IO.File]::ReadAllText((Join-Path $done '02.txt'), $script:Utf8)
        Assert-True -Condition ($t2 -match 'код возврата: 7') -Name 'smoke: ненулевой код возврата 7 записан'
    } else {
        Assert-True -Condition $false -Name 'smoke: done\02.txt создан'
    }

    if (Test-Path -LiteralPath (Join-Path $done '02.done')) {
        $m2 = [System.IO.File]::ReadAllText((Join-Path $done '02.done'), $script:Utf8)
        Assert-True -Condition ($m2 -match 'результат: ошибка \(код 7\)') -Name 'smoke: метка .done помечает ненулевой код как ошибку'
        Assert-True -Condition ($m2 -notmatch 'результат: ок') -Name 'smoke: провал не помечен как успех'
    } else {
        Assert-True -Condition $false -Name 'smoke: done\02.done создан'
    }

    if (Test-Path -LiteralPath (Join-Path $done '03.txt')) {
        $t3 = [System.IO.File]::ReadAllText((Join-Path $done '03.txt'), $script:Utf8)
        Assert-True -Condition ($t3 -match 'хвост без перевода строки') -Name 'smoke: неполная последняя строка дописана (-Final)'
    } else {
        Assert-True -Condition $false -Name 'smoke: done\03.txt создан'
    }

    if (Test-Path -LiteralPath (Join-Path $done '04.txt')) {
        $t4 = [System.IO.File]::ReadAllText((Join-Path $done '04.txt'), $script:Utf8)
        Assert-True -Condition ($t4 -match 'таймаут \(5 с\)') -Name 'smoke: таймаут зафиксирован в логе'
        Assert-True -Condition ($t4 -notmatch 'не должно дойти') -Name 'smoke: вывод убитой команды не попал в лог'
    } else {
        Assert-True -Condition $false -Name 'smoke: done\04.txt создан'
    }

    if (Test-Path -LiteralPath (Join-Path $done '05.txt')) {
        $t5 = [System.IO.File]::ReadAllText((Join-Path $done '05.txt'), $script:Utf8)
        Assert-True -Condition ($t5 -match 'код возврата: 5') -Name 'smoke: код 5 (провал серии) записан драйвером'
    } else {
        Assert-True -Condition $false -Name 'smoke: done\05.txt создан'
    }

    if (Test-Path -LiteralPath (Join-Path $done '05.done')) {
        $m5 = [System.IO.File]::ReadAllText((Join-Path $done '05.done'), $script:Utf8)
        Assert-True -Condition ($m5 -match 'результат: ошибка \(код 5\)') -Name 'smoke: exit 5 помечен в .done как ошибка'
        Assert-True -Condition ($m5 -notmatch 'результат: ок') -Name 'smoke: exit 5 не выглядит успехом'
    } else {
        Assert-True -Condition $false -Name 'smoke: done\05.done создан'
    }

    $leftovers = @(Get-ChildItem -LiteralPath $done -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^_' })
    Assert-Equal -Actual $leftovers.Count -Expected 0 -Name 'smoke: временные файлы драйвера удалены' -Detail (($leftovers | ForEach-Object { $_.Name }) -join ', ')

    $pngs = @()
    if (Test-Path -LiteralPath $shots) { $pngs = @(Get-ChildItem -LiteralPath $shots -Filter '*.png' -ErrorAction SilentlyContinue) }
    Assert-Equal -Actual $pngs.Count -Expected 0 -Name 'smoke: -NoScreenshot не создаёт кадров'

    $order = @()
    foreach ($f in @('01.txt', '02.txt', '03.txt', '04.txt', '05.txt')) {
        $p = Join-Path $done $f
        if (Test-Path -LiteralPath $p) { $order += $f }
    }
    Assert-Equal -Actual ($order -join ',') -Expected '01.txt,02.txt,03.txt,04.txt,05.txt' -Name 'smoke: команды выполнены в порядке имён'

    # Повторный запуск: выполненные команды пропускаются по меткам .done.
    # Вывод драйвера идёт в [Console]::Out (а не в конвейер), поэтому проверяем
    # по файлам: повторный прогон не должен переписывать готовые done\NN.txt.
    $stamps = @{}
    foreach ($f in @('01.txt', '02.txt', '03.txt', '04.txt', '05.txt')) {
        $p = Join-Path $done $f
        if (Test-Path -LiteralPath $p) { $stamps[$f] = (Get-Item -LiteralPath $p).LastWriteTimeUtc.Ticks }
    }
    Start-Sleep -Milliseconds 1100
    $savedPath = $env:PATH
    $env:PATH = $shimDir + [System.IO.Path]::PathSeparator + $env:PATH
    try {
        $null = & (Join-Path $smokeTools 'run_lab.ps1') -Root $smokeTools -NoScreenshot -TimeoutSec 5 -IdleExitSec 1 2>&1
    } finally {
        $env:PATH = $savedPath
    }
    $changed = @()
    foreach ($f in $stamps.Keys) {
        $p = Join-Path $done $f
        $now = (Get-Item -LiteralPath $p).LastWriteTimeUtc.Ticks
        if ($now -ne $stamps[$f]) { $changed += $f }
    }
    Assert-Equal -Actual ($changed -join ',') -Expected '' -Name 'smoke: повторный запуск не перевыполняет готовые команды'
}

Write-Host ''
Write-Host '=== 8. Кольцевой буфер: pre-exit кадры и явный провал ==='

$ringDir = New-TestDir 'lab5ring'
$pngBytes = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
$okCapture = { param($FramePath) [System.IO.File]::WriteAllBytes($FramePath, $pngBytes) }

$frameOk = Save-LabRingFrame -Path (Join-Path $ringDir 'ok.png') -Capture $okCapture
Assert-True -Condition $frameOk.Ok -Name 'Save-LabRingFrame: кадр записан'
Assert-Equal -Actual $frameOk.Bytes -Expected $pngBytes.Length -Name 'Save-LabRingFrame: размер кадра проверен'
Assert-True -Condition ($frameOk.At -is [datetime]) -Name 'Save-LabRingFrame: время кадра зафиксировано'
Assert-True -Condition ($frameOk.Seconds -ge 0) -Name 'Save-LabRingFrame: длительность кадра измерена'
Assert-True -Condition ($frameOk.StartedAt -is [datetime]) -Name 'Save-LabRingFrame: зафиксировано начало захвата'
Assert-True -Condition (Test-LabPngFile -Path (Join-Path $ringDir 'ok.png')) -Name 'Test-LabPngFile: целый PNG распознан'

$tornLen = [int][math]::Floor($pngBytes.Length / 2)
$tornPath = Join-Path $ringDir 'torn.png'
[System.IO.File]::WriteAllBytes($tornPath, [byte[]]$pngBytes[0..$tornLen])
Assert-True -Condition (-not (Test-LabPngFile -Path $tornPath)) -Name 'Test-LabPngFile: обрезанный PNG отвергнут'
Assert-True -Condition (-not (Test-LabFrameFile -Path $tornPath)) -Name 'Test-LabFrameFile: обрезанный PNG не считается кадром'
$tornFrame = Save-LabRingFrame -Path (Join-Path $ringDir 'torn2.png') -Capture { param($FramePath) [System.IO.File]::WriteAllBytes($FramePath, [byte[]]$pngBytes[0..$tornLen]) }
Assert-True -Condition (-not $tornFrame.Ok) -Name 'Save-LabRingFrame: повреждённый PNG - провал'
Assert-True -Condition ($tornFrame.Error -match 'повреждён') -Name 'Save-LabRingFrame: причина повреждения сохранена' -Detail $tornFrame.Error

$frameEmpty = Save-LabRingFrame -Path (Join-Path $ringDir 'empty.png') -Capture { param($FramePath) }
Assert-True -Condition (-not $frameEmpty.Ok) -Name 'Save-LabRingFrame: пустой кадр - провал'
Assert-True -Condition ($frameEmpty.Error -match 'не записан') -Name 'Save-LabRingFrame: причина пустого кадра сохранена' -Detail $frameEmpty.Error

$frameThrow = Save-LabRingFrame -Path (Join-Path $ringDir 'throw.png') -Capture { param($FramePath) throw 'CopyFromScreen: The handle is invalid' }
Assert-True -Condition (-not $frameThrow.Ok) -Name 'Save-LabRingFrame: исключение захвата - провал'
Assert-True -Condition ($frameThrow.Error -match 'handle is invalid') -Name 'Save-LabRingFrame: текст исключения не проглочен' -Detail $frameThrow.Error
Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $ringDir 'throw.png'))) -Name 'Save-LabRingFrame: битый кадр удалён с диска'

$ringFile = Join-Path $ringDir 'ring.png'
[System.IO.File]::WriteAllBytes($ringFile, $pngBytes)
Assert-Equal -Actual (Test-LabRingFrameUsable -Path $ringFile -LastFrameAt (Get-Date)) -Expected '' -Name 'Test-LabRingFrameUsable: свежий непустой кадр годится'
Assert-True -Condition ((Test-LabRingFrameUsable -Path $ringFile -LastFrameAt (Get-Date).AddSeconds(-30) -MaxStaleSec 5) -ne '') -Name 'Test-LabRingFrameUsable: устаревший кадр не годится'
Assert-True -Condition ((Test-LabRingFrameUsable -Path (Join-Path $ringDir 'none.png') -LastFrameAt (Get-Date)) -ne '') -Name 'Test-LabRingFrameUsable: отсутствующий кадр не годится'
Assert-True -Condition ((Test-LabRingFrameUsable -Path $ringFile -LastFrameAt $null) -ne '') -Name 'Test-LabRingFrameUsable: без отметки времени кадр не годится'

$probeWorker = @{ Calls = 0 }
$loopWorker = Invoke-LabRingLoop -Probe {
    $probeWorker.Calls++
    if ($probeWorker.Calls -ge 3) {
        return [pscustomobject]@{ Code = 1; FirstGone = 222; RemainingTids = @(333) }
    }
    return [pscustomobject]@{ Code = 0; FirstGone = 0; RemainingTids = @(222, 333) }
} -Capture $okCapture -TmpPath (Join-Path $ringDir 'workers.tmp.png') -LastPath (Join-Path $ringDir 'workers.png') -TimeoutSec 10 -PollMs 1
Assert-Equal -Actual $loopWorker.Stopped -Expected 'first' -Name 'кольцо worker: завершение одного TID распознано'
Assert-Equal -Actual $loopWorker.FirstGone -Expected 222 -Name 'кольцо worker: ID завершившегося потока сохранён'
Assert-Equal -Actual ($loopWorker.RemainingTids -join ',') -Expected '333' -Name 'кольцо worker: оставшийся TID того же snapshot сохранён'

$probeAmbiguous = @{ Calls = 0 }
$loopAmbiguous = Invoke-LabRingLoop -Probe {
    $probeAmbiguous.Calls++
    if ($probeAmbiguous.Calls -ge 3) {
        return [pscustomobject]@{ Code = -2; FirstGone = 0; RemainingTids = @() }
    }
    return [pscustomobject]@{ Code = 0; FirstGone = 0; RemainingTids = @(222, 333) }
} -Capture $okCapture -TmpPath (Join-Path $ringDir 'ambiguous.tmp.png') -LastPath (Join-Path $ringDir 'ambiguous.png') -TimeoutSec 10 -PollMs 1
Assert-Equal -Actual $loopAmbiguous.Stopped -Expected 'ambiguous' -Name 'кольцо worker: одновременное исчезновение помечено неоднозначным'
Assert-Equal -Actual $loopAmbiguous.FirstGone -Expected 0 -Name 'кольцо worker: неоднозначный результат не придумывает первый TID'

$probePlain = @{ Calls = 0 }
$loopFirst = Invoke-LabRingLoop -Probe { $probePlain.Calls++; if ($probePlain.Calls -ge 3) { return 4242 }; return 0 } -Capture $okCapture -TmpPath (Join-Path $ringDir 'l1.tmp.png') -LastPath (Join-Path $ringDir 'l1.png') -TimeoutSec 10 -PollMs 1
Assert-Equal -Actual $loopFirst.Stopped -Expected 'first' -Name 'буфер: останов по первому завершению'
Assert-Equal -Actual $loopFirst.FirstGone -Expected 4242 -Name 'буфер: идентификатор завершившегося сохранён'
Assert-True -Condition ($loopFirst.Frames -ge 1) -Name ('буфер: кадры до выхода есть (' + $loopFirst.Frames + ')')
Assert-True -Condition (Test-LabFrameFile -Path (Join-Path $ringDir 'l1.png')) -Name 'буфер: последний кадр на месте'
Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $ringDir 'l1.tmp.png'))) -Name 'буфер: временный кадр убран'

$probePost = @{ Calls = 0 }
$loopPost = Invoke-LabRingLoop -Probe { $probePost.Calls++; if ($probePost.Calls -ge 2) { return 777 }; return 0 } -Capture $okCapture -TmpPath (Join-Path $ringDir 'l2.tmp.png') -LastPath (Join-Path $ringDir 'l2.png') -TimeoutSec 10 -PollMs 1
Assert-Equal -Actual $loopPost.Frames -Expected 0 -Name 'буфер: кадр, снятый после выхода, не засчитывается'
Assert-Equal -Actual $loopPost.DeadFrames -Expected 1 -Name 'буфер: кадр после выхода отброшен'
Assert-Equal -Actual $loopPost.FirstGone -Expected 777 -Name 'буфер: выход зафиксирован и в этом случае'
Assert-True -Condition (-not (Test-LabFrameFile -Path (Join-Path $ringDir 'l2.png'))) -Name 'буфер: отброшенный кадр не становится "последним"'

$probeFail = @{ Calls = 0 }
$loopFail = Invoke-LabRingLoop -Probe { $probeFail.Calls++; if ($probeFail.Calls -ge 3) { return 55 }; return 0 } -Capture { param($FramePath) throw 'boom: capture failed' } -TmpPath (Join-Path $ringDir 'l3.tmp.png') -LastPath (Join-Path $ringDir 'l3.png') -TimeoutSec 10 -PollMs 1
Assert-Equal -Actual $loopFail.Frames -Expected 0 -Name 'буфер: при сбоях захвата кадров нет'
Assert-True -Condition ($loopFail.Failures -ge 1) -Name ('буфер: сбои захвата посчитаны (' + $loopFail.Failures + ')')
Assert-True -Condition ($loopFail.LastError -match 'boom') -Name 'буфер: причина сбоя сохранена' -Detail $loopFail.LastError
Assert-True -Condition (-not (Test-LabFrameFile -Path (Join-Path $ringDir 'l3.png'))) -Name 'буфер: после сбоев "последнего" кадра нет'

$loopTimeout = Invoke-LabRingLoop -Probe { return 0 } -Capture $okCapture -TmpPath (Join-Path $ringDir 'l4.tmp.png') -LastPath (Join-Path $ringDir 'l4.png') -TimeoutSec 1 -PollMs 20
Assert-Equal -Actual $loopTimeout.Stopped -Expected 'timeout' -Name 'буфер: таймаут отличим от выхода'
Assert-True -Condition ($loopTimeout.Frames -ge 1) -Name 'буфер: за время ожидания кадры всё равно сняты'

$loopLog = New-Object System.Collections.ArrayList
$probeLog = @{ Calls = 0 }
$null = Invoke-LabRingLoop -Probe { $probeLog.Calls++; return 0 } -Capture { param($FramePath) throw 'boom: ещё раз' } -TmpPath (Join-Path $ringDir 'l5.tmp.png') -LastPath (Join-Path $ringDir 'l5.png') -TimeoutSec 1 -PollMs 20 -OnLog { param($Text) [void]$loopLog.Add([string]$Text) }
Assert-True -Condition ($loopLog.Count -ge 1 -and [string]$loopLog[0] -match 'не снят') -Name 'буфер: сбой захвата печатается в лог, а не глотается' -Detail (($loopLog -join ' | '))

$stalePath = Join-Path $ringDir 'l6.png'
[System.IO.File]::WriteAllBytes($stalePath, $pngBytes)
$loopStale = Invoke-LabRingLoop -Probe { return 9001 } -Capture $okCapture -TmpPath (Join-Path $ringDir 'l6.tmp.png') -LastPath $stalePath -TimeoutSec 5 -PollMs 1
Assert-Equal -Actual $loopStale.Frames -Expected 0 -Name 'сценарий 05b (0 кадров): кадров нет'
Assert-Equal -Actual $loopStale.Stopped -Expected 'first' -Name 'сценарий 05b (0 кадров): выход зафиксирован'
Assert-True -Condition (-not (Test-Path -LiteralPath $stalePath)) -Name 'сценарий 05b (0 кадров): кадр прошлого прогона удалён'
$staleReason = Test-LabRingFrameUsable -Path $stalePath -LastFrameAt $loopStale.LastFrameAt
Assert-True -Condition ($staleReason -ne '') -Name 'сценарий 05b (0 кадров): серия обязана упасть с кодом 5, а не подставить кадр' -Detail $staleReason

$staleTmpPath = Join-Path $ringDir 'l7.tmp.png'
[System.IO.File]::WriteAllBytes($staleTmpPath, $pngBytes)
$strictCapture = { param($FramePath) if (Test-Path -LiteralPath $FramePath) { throw 'tmp не удалён до захвата' }; [System.IO.File]::WriteAllBytes($FramePath, $pngBytes) }
$probeAgain = @{ Calls = 0 }
$loopAgain = Invoke-LabRingLoop -Probe { $probeAgain.Calls++; if ($probeAgain.Calls -ge 3) { return 31337 }; return 0 } -Capture $strictCapture -TmpPath $staleTmpPath -LastPath (Join-Path $ringDir 'l7.png') -TimeoutSec 10 -PollMs 1
Assert-Equal -Actual $loopAgain.Failures -Expected 0 -Name 'повторный запуск: старый _ring_*.tmp.png не мешает захвату'
Assert-Equal -Actual $loopAgain.Frames -Expected 1 -Name 'повторный запуск: кадр снят и засчитан'
Assert-Equal -Actual $loopAgain.FirstGone -Expected 31337 -Name 'повторный запуск: выход зафиксирован'
Assert-True -Condition (-not (Test-Path -LiteralPath $staleTmpPath)) -Name 'повторный запуск: tmp убран после кадра'

$loopProbeError = Invoke-LabRingLoop -Probe { throw 'probe: access denied' } -Capture $okCapture -TmpPath (Join-Path $ringDir 'l8.tmp.png') -LastPath (Join-Path $ringDir 'l8.png') -TimeoutSec 5 -PollMs 1
Assert-Equal -Actual $loopProbeError.Stopped -Expected 'probe-error' -Name 'буфер: сбой опроса цели отличим от выхода'
Assert-True -Condition ($loopProbeError.LastError -match 'access denied') -Name 'буфер: причина сбоя опроса сохранена' -Detail $loopProbeError.LastError
Assert-True -Condition (-not (Test-LabFrameFile -Path (Join-Path $ringDir 'l8.png'))) -Name 'буфер: при сбое опроса "последнего" кадра нет'

$probeAfter = @{ Calls = 0 }
$loopAfterError = Invoke-LabRingLoop -Probe { $probeAfter.Calls++; if ($probeAfter.Calls -ge 2) { throw 'probe: after capture' }; return 0 } -Capture $okCapture -TmpPath (Join-Path $ringDir 'l9.tmp.png') -LastPath (Join-Path $ringDir 'l9.png') -TimeoutSec 5 -PollMs 1
Assert-Equal -Actual $loopAfterError.Stopped -Expected 'probe-error' -Name 'буфер: сбой опроса после кадра - провал, а не "выход"'
Assert-Equal -Actual $loopAfterError.Frames -Expected 0 -Name 'буфер: непроверенный кадр не засчитывается'

Assert-True -Condition (Test-LabProcessAlive -ProcessId $PID) -Name 'Test-LabProcessAlive: текущий процесс жив'
Assert-True -Condition (-not (Test-LabProcessAlive -ProcessId 999999)) -Name 'Test-LabProcessAlive: несуществующий PID завершён'
Assert-True -Condition (-not (Test-LabProcessAlive -ProcessId 0)) -Name 'Test-LabProcessAlive: PID 0 не считается живым'

foreach ($capName in @('capture_05b.ps1', 'capture_05c.ps1')) {
    $capText = [System.IO.File]::ReadAllText((Join-Path $script:Tools $capName), $script:Utf8)
    Assert-True -Condition ($capText -match 'Invoke-LabRingLoop') -Name ($capName + ': использует общий кольцевой буфер')
    Assert-True -Condition ($capText -match 'Test-LabRingFrameUsable') -Name ($capName + ': проверяет пригодность кадра из буфера')
    Assert-True -Condition ($capText -match 'd_first_finish_MISSING') -Name ($capName + ': провал буфера пишет диагностику')
    Assert-True -Condition ($capText -match 'exit 5') -Name ($capName + ': провал серии возвращает код 5')
    Assert-True -Condition ($capText -notmatch 'Save-LabScreenshot -Path \$firstShot') -Name ($capName + ': нет подмены d_first_finish кадром после выхода')
    Assert-True -Condition ($capText -notmatch 'Save-LabScreenshot -Path \$ringTmp') -Name ($capName + ': кольцевой кадр не снимается в пустом try')
    Assert-True -Condition ($capText -match 'кольцевой буфер: кадров в буфере') -Name ($capName + ': сводка содержит статистику буфера')
}

if (-not $KeepTemp -or $KeepTemp -eq '') {
    Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Directory -Filter 'lab5*' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-30) } |
        ForEach-Object { try { Remove-Item -LiteralPath $_.FullName -Recurse -Force } catch { } }
} else {
    Write-Host ('[i] temp сохранён: ' + $KeepTemp)
}

Write-Host ''
Write-Host ('=== ИТОГ: ok ' + $script:Pass + ', провал ' + $script:Fail + ', пропущено ' + $script:Skip + ' ===')
if ($script:Fail -gt 0) { exit 1 }
exit 0
