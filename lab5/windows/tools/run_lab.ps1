# ============================================================================
# run_lab.ps1 - драйвер очереди команд ЛР5 (Windows, PowerShell 5.1)
#
# Работает в открытом консольном окне: в цикле берёт queue\<NN>_<имя>.cmd
# (сортировка по имени), печатает приглашение "PS> cmd /c queue\...",
# выполняет команду через cmd.exe /c, печатает её вывод по мере появления,
# снимает скриншот всего экрана в shots\<NN>_<имя>.png и пишет
# done\<NN>.txt (команда + вывод + код возврата) и метку done\<NN>.done.
#
# Запуск (обычно через start_driver.ps1):
#   powershell -NoProfile -ExecutionPolicy Bypass -File run_lab.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File run_lab.ps1 -KeepAlive
# ============================================================================

[CmdletBinding()]
param(
    [string]$Root = '',
    [int]$TimeoutSec = 600,
    [switch]$KeepAlive,
    [int]$IdleExitSec = 20,
    [switch]$NoScreenshot,
    [switch]$NoSelfLayout,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lab_common.ps1')
Initialize-LabConsole
Initialize-LabDpi
try { $Host.UI.RawUI.WindowTitle = 'OS5 lab5 harness (run_lab)' } catch { }

$utf8 = New-Object System.Text.UTF8Encoding($false)

$work = Resolve-LabRoot -Requested $Root -Fallback $PSScriptRoot
$queueDir = Join-Path $work 'queue'
$shotsDir = Join-Path $work 'shots'
$doneDir = Join-Path $work 'done'
foreach ($d in @($shotsDir, $doneDir)) {
    if (-not (Test-Path -LiteralPath $d)) { $null = New-Item -ItemType Directory -Path $d -Force }
}

# Драйвер занимает левую половину рабочего стола: правая остаётся окнам
# дочерних процессов, которые раскладывают capture_05b/capture_05c.
if (-not $NoSelfLayout) {
    try {
        $area = Get-LabWorkingArea
        $hwnd = [LabWin32]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) {
            $w = [int][math]::Floor($area.Width / 2)
            [void](Set-LabWindowRect -Handle $hwnd -X $area.Left -Y $area.Top -Width $w -Height $area.Height)
        }
    } catch {
        Write-LabLine ('[!] не удалось разложить окно драйвера: ' + $_.Exception.Message)
    }
}

Write-LabLine '============================================================'
Write-LabLine (' Драйвер ЛР5. Рабочий каталог: ' + $work)
Write-LabLine (' Очередь:    ' + $queueDir)
Write-LabLine (' Скриншоты:  ' + $shotsDir)
Write-LabLine (' Логи команд: ' + $doneDir)
Write-LabLine (' Таймаут команды: ' + $TimeoutSec + ' с, опрос очереди: 0.5 с')
Write-LabLine '============================================================'

# ---------------------------------------------------------------------------
# Дочитывание растущего файла вывода: печатаем только завершённые строки,
# поэтому кириллица не рвётся на границе UTF-8 последовательности.
# ---------------------------------------------------------------------------
function Read-LabNewOutput {
    param([string]$Path, [int]$Printed, [switch]$Final)

    if (-not (Test-Path -LiteralPath $Path)) { return $Printed }
    $text = ''
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $sr = New-Object System.IO.StreamReader($fs, (New-Object System.Text.UTF8Encoding($false)))
            $text = $sr.ReadToEnd()
            $sr.Dispose()
        } finally {
            $fs.Dispose()
        }
    } catch {
        return $Printed
    }
    if ($text.Length -le $Printed) { return $Printed }

    $chunk = $text.Substring($Printed)
    if (-not $Final) {
        $idx = $chunk.LastIndexOf("`n")
        if ($idx -lt 0) { return $Printed }
        $chunk = $chunk.Substring(0, $idx + 1)
    }
    [Console]::Out.Write($chunk)
    [Console]::Out.Flush()
    return $Printed + $chunk.Length
}

# ---------------------------------------------------------------------------
# Одна команда очереди: запуск, живой вывод, таймаут, скриншот, логи
# ---------------------------------------------------------------------------
function Invoke-LabQueueCommand {
    param(
        [System.IO.FileInfo]$File,
        [string]$Work,
        [string]$Shots,
        [string]$Done,
        [int]$TimeoutSec,
        [switch]$NoScreenshot
    )

    $name = $File.Name
    $nn = Get-LabQueueNumber -Name $name
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $txtPath = Join-Path $Done ($nn + '.txt')
    $markPath = Join-Path $Done ($nn + '.done')
    $shotPath = Join-Path $Shots ($stem + '.png')

    $startTime = Get-Date
    Write-LabLine ''
    Write-LabLine ('PS> cmd /c queue\' + $name)
    Write-LabLine ('--- старт: ' + $startTime.ToString('HH:mm:ss') + ' ---')

    # Обёртка: chcp 65001 + call команды + перенаправление вывода в файл.
    # Вывод идёт в файл, драйвер дочитывает его и печатает - так одновременно
    # есть и живая картинка в консоли, и полный текст в done\<NN>.txt.
    $tmpCmd = Join-Path $Done ('_' + $nn + '.run.cmd')
    $tmpOut = Join-Path $Done ('_' + $nn + '.out.tmp')
    if (Test-Path -LiteralPath $tmpOut) { Remove-Item -LiteralPath $tmpOut -Force }

    $body = "@echo off`r`n"
    $body += "chcp 65001>nul`r`n"
    $body += 'call "' + $File.FullName + '" > "' + $tmpOut + '" 2>&1' + "`r`n"
    $body += "exit /b %errorlevel%`r`n"
    [System.IO.File]::WriteAllText($tmpCmd, $body, $utf8)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    if (-not $psi.FileName) { $psi.FileName = 'cmd.exe' }
    $psi.Arguments = '/d /c ""' + $tmpCmd + '""'
    $psi.WorkingDirectory = $Work
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $false
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false

    $proc = $null
    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
    } catch {
        $msg = '[!] не удалось запустить cmd.exe: ' + $_.Exception.Message
        Write-LabLine $msg
        $failText = '=== ' + $name + " ===`r`n"
        $failText += 'команда: cmd /c queue\' + $name + "`r`n"
        $failText += 'результат: ' + $msg + "`r`n"
        [System.IO.File]::WriteAllText($txtPath, $failText, $utf8)
        [System.IO.File]::WriteAllText($markPath, ('команда: ' + $name + "`r`nрезультат: ошибка запуска`r`n"), $utf8)
        foreach ($tmp in @($tmpCmd, $tmpOut)) {
            if (Test-Path -LiteralPath $tmp) { try { Remove-Item -LiteralPath $tmp -Force } catch { } }
        }
        return
    }

    $printed = 0
    $timedOut = $false
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $proc.HasExited) {
        $printed = Read-LabNewOutput -Path $tmpOut -Printed $printed
        if ($watch.Elapsed.TotalSeconds -ge $TimeoutSec) {
            $timedOut = $true
            break
        }
        Start-Sleep -Milliseconds 200
    }
    $printed = Read-LabNewOutput -Path $tmpOut -Printed $printed -Final

    if ($timedOut) {
        Write-LabLine ''
        Write-LabLine ('[!] ТАЙМАУТ ' + $TimeoutSec + ' с - снимаю дерево процессов PID ' + $proc.Id)
        Stop-LabTree -ProcessId $proc.Id
        try { [void]$proc.WaitForExit(5000) } catch { }
    } else {
        try { [void]$proc.WaitForExit(5000) } catch { }
    }
    $watch.Stop()

    $code = 0
    $codeText = ''
    if ($timedOut) {
        $codeText = 'таймаут (' + $TimeoutSec + ' с)'
    } else {
        try { $code = $proc.ExitCode } catch { $code = -1 }
        $codeText = [string]$code
    }
    $endTime = Get-Date

    # Кадр снимаем до записи файлов: на экране ещё виден вывод команды.
    if (-not $NoScreenshot) {
        try {
            $null = Save-LabScreenshot -Path $shotPath -DelayMs 350
        } catch {
            Write-LabLine ('[!] скриншот не снят: ' + $_.Exception.Message)
        }
    }

    $outText = ''
    if (Test-Path -LiteralPath $tmpOut) {
        try { $outText = [System.IO.File]::ReadAllText($tmpOut, $utf8) } catch { $outText = '' }
    }

    $header = '=== ' + $name + " ===`r`n"
    $header += 'команда: cmd /c queue\' + $name + "`r`n"
    $header += 'начало: ' + $startTime.ToString('yyyy-MM-dd HH:mm:ss') + "`r`n"
    $header += 'конец:  ' + $endTime.ToString('yyyy-MM-dd HH:mm:ss') + "`r`n"
    $header += 'длительность, с: ' + [math]::Round($watch.Elapsed.TotalSeconds, 1) + "`r`n"
    $header += 'код возврата: ' + $codeText + "`r`n"
    $header += 'скриншот: ' + $shotPath + "`r`n"
    $header += "`r`n--- вывод ---`r`n"
    [System.IO.File]::WriteAllText($txtPath, $header + $outText, $utf8)

    $markResult = 'ок'
    if ($timedOut) { $markResult = 'таймаут' }
    elseif ($code -ne 0) { $markResult = 'ошибка (код ' + $code + ')' }
    if ($markResult -ne 'ок') {
        Write-LabLine ('[!] результат команды: ' + $markResult + ' - ненулевой код не считается успехом серии')
    }

    $mark = 'команда: ' + $name + "`r`n"
    $mark += 'результат: ' + $markResult + "`r`n"
    $mark += 'код: ' + $codeText + "`r`n"
    $mark += 'длительность, с: ' + [math]::Round($watch.Elapsed.TotalSeconds, 1) + "`r`n"
    $mark += 'вывод: ' + $txtPath + "`r`n"
    $mark += 'скриншот: ' + $shotPath + "`r`n"
    [System.IO.File]::WriteAllText($markPath, $mark, $utf8)

    Write-LabLine ''
    Write-LabLine ('--- конец: ' + $endTime.ToString('HH:mm:ss') + ', код: ' + $codeText + ', вывод: done\' + $nn + '.txt, скрин: shots\' + $stem + '.png ---')

    foreach ($tmp in @($tmpCmd, $tmpOut)) {
        if (Test-Path -LiteralPath $tmp) {
            try { Remove-Item -LiteralPath $tmp -Force } catch { }
        }
    }
}

# ---------------------------------------------------------------------------
# Основной цикл
# ---------------------------------------------------------------------------

$processed = @{}
if (-not $Force) {
    $existing = @(Get-ChildItem -LiteralPath $queueDir -Filter '*.cmd' -ErrorAction SilentlyContinue)
    foreach ($f in $existing) {
        $nn = Get-LabQueueNumber -Name $f.Name
        if (Test-Path -LiteralPath (Join-Path $doneDir ($nn + '.done'))) { $processed[$f.Name] = $true }
    }
    if ($processed.Count -gt 0) {
        Write-LabLine ('[.] уже отмечены как выполненные: ' + $processed.Count + ' команд (перезапуск с -Force игнорирует метки)')
    }
}

$emptyPolls = 0
while ($true) {
    $all = @(Get-ChildItem -LiteralPath $queueDir -Filter '*.cmd' -ErrorAction SilentlyContinue | Sort-Object Name)
    $pending = @()
    foreach ($f in $all) {
        if (-not $processed.ContainsKey($f.Name)) { $pending += $f }
    }

    if ($pending.Count -eq 0) {
        if ($emptyPolls -eq 0) {
            if ($KeepAlive) {
                Write-LabLine '[.] очередь пуста - ждём новые *.cmd (Ctrl+C - выход)'
            } else {
                Write-LabLine ('[.] очередь пуста - выход через ' + $IdleExitSec + ' с без новых команд (Ctrl+C - сразу)')
            }
        }
        Start-Sleep -Milliseconds 500
        $emptyPolls++
        if (-not $KeepAlive) {
            if (($emptyPolls * 0.5) -ge $IdleExitSec) { break }
        }
        continue
    }

    $emptyPolls = 0
    $file = $pending[0]
    try {
        Invoke-LabQueueCommand -File $file -Work $work -Shots $shotsDir -Done $doneDir -TimeoutSec $TimeoutSec -NoScreenshot:$NoScreenshot
    } catch {
        Write-LabLine ('[!] сбой на команде ' + $file.Name + ': ' + $_.Exception.Message)
        $nn = Get-LabQueueNumber -Name $file.Name
        $errPath = Join-Path $doneDir ($nn + '.txt')
        [System.IO.File]::WriteAllText($errPath, ('команда: ' + $file.Name + "`r`nошибка драйвера: " + $_.Exception.ToString() + "`r`n"), $utf8)
        [System.IO.File]::WriteAllText((Join-Path $doneDir ($nn + '.done')), ('команда: ' + $file.Name + "`r`nрезультат: ошибка драйвера`r`n"), $utf8)
    }
    $processed[$file.Name] = $true
}

Write-LabLine ''
Write-LabLine '=== драйвер завершён ==='
Write-LabLine ('метки: ' + $doneDir)
