# top5.ps1 - монитор топ-5 процессов по загрузке процессора и памяти (уровень 9)
# Параметр -Interval задаёт период обновления в секундах (по умолчанию 5),
# -Count - сколько кадров вывести (0 = бесконечно, до Ctrl+C).
#
# Clear-Host при перенаправлении вывода очищает уже записанный буфер,
# поэтому в режиме с файлом вывода (-Count > 0) очистки нет: иначе каждый
# кадр, кроме последнего, просто исчезает из вывода.
param(
    [int]$Interval = 5,
    [int]$Count = 0
)

if ($Interval -le 0) {
    Write-Host "Ошибка: интервал должен быть положительным целым числом секунд" -ForegroundColor Red
    exit 1
}

function Format-Dep {
    param([long]$Value)
    if ($Value -ge 1GB) { return "{0:N2} GB" -f ($Value / 1GB) }
    if ($Value -ge 1MB) { return "{0:N2} MB" -f ($Value / 1MB) }
    if ($Value -ge 1KB) { return "{0:N2} KB" -f ($Value / 1KB) }
    return "$Value B"
}

$frame = 0
while ($true) {
    # Clear-Host только в бесконечном режиме на экране.
    if ($Count -eq 0) { Clear-Host }

    $frame++
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $byCpu = @(Get-Process | Sort-Object CPU -Descending | Select-Object -First 5)
    $byMem = @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5)

    Write-Host "============================================================"
    Write-Host " МОНИТОР ПРОЦЕССОВ - ТОП-5"
    Write-Host "============================================================"
    Write-Host " Время:   $now"
    Write-Host " Интервал: $Interval с   Кадр: $frame"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host " ТОП-5 ПО ЗАГРУЗКЕ ПРОЦЕССОРА"
    Write-Host (" {0,-24} {1,12} {2,14}" -f "ИМЯ ПРОЦЕССА", "CPU (с)", "ПАМЯТЬ")
    Write-Host ("-" * 52)
    foreach ($p in $byCpu) {
        $cpu = if ($null -ne $p.CPU) { [math]::Round($p.CPU, 1) } else { 0 }
        Write-Host (" {0,-24} {1,12} {2,14}" -f $p.ProcessName, $cpu, (Format-Dep $p.WorkingSet64))
    }

    Write-Host ""
    Write-Host " ТОП-5 ПО ИСПОЛЬЗОВАНИЮ ПАМЯТИ"
    Write-Host (" {0,-24} {1,14} {2,12}" -f "ИМЯ ПРОЦЕССА", "ПАМЯТЬ", "CPU (с)")
    Write-Host ("-" * 52)
    foreach ($p in $byMem) {
        $cpu = if ($null -ne $p.CPU) { [math]::Round($p.CPU, 1) } else { 0 }
        Write-Host (" {0,-24} {1,14} {2,12}" -f $p.ProcessName, (Format-Dep $p.WorkingSet64), $cpu)
    }
    Write-Host ""

    if ($Count -gt 0 -and $frame -ge $Count) { break }
    Start-Sleep -Seconds $Interval
}

Write-Host "Монитор остановлен: выведено кадров - $frame"