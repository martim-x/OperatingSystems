# tempconv.ps1 - конвертер температур (уровень 8, PowerShell)
# Перевод между Кельвином, Цельсием и Фаренгейтом.
# Исходная единица определяется по суффиксу: 100K, 100C или 100F.
# Файл с исходными значениями, по одному в строке. Нужен для автоматического
# прогона: Read-Host игнорирует перенаправленный stdin и блокируется.
#
# Ключ -FileIn разбирается вручную из $args, а не объявляется параметром:
# объявленный [string]$FileIn является позиционным и первым же значением
# (100K, 100C, ...) перехватывался как путь к файлу - скрипт падал с
# FileNotFoundException вместо convertsения температур.

$FileIn = $null
$values = @()
if ($args.Count -gt 0 -and $args[0] -eq "-FileIn") {
    $FileIn = $args[1]
    if ($args.Count -gt 2) { $values = $args[2..($args.Count - 1)] }
} else {
    $values = $args
}

# Файл ввода читаем байтами и декодируем кодовой страницей консоли:
# Get-Content без -Encoding берёт ANSI и ломает кириллицу (866 против 1251).
function Get-ConsoleLines([string]$path) {
    $enc = [System.Text.Encoding]::GetEncoding([int][Console]::OutputEncoding.CodePage)
    $text = $enc.GetString([System.IO.File]::ReadAllBytes($path))
    foreach ($l in ($text -split "`r?`n")) {
        if ($l.Trim() -eq "") { continue }
        $l.Trim()
    }
}

function To-Kelvin([double]$v, [string]$unit) {
    switch ($unit.ToUpper()) {
        "K" { return $v }
        "C" { return $v + 273.15 }
        "F" { return ($v - 32) * 5 / 9 + 273.15 }
        default { return $null }
    }
}
function From-Kelvin([double]$k, [string]$unit) {
    switch ($unit.ToUpper()) {
        "K" { return $k }
        "C" { return $k - 273.15 }
        "F" { return ($k - 273.15) * 9 / 5 + 32 }
        default { return $null }
    }
}

function Convert-Value([string]$arg) {
    if ($arg -notmatch '^\s*(-?\d+(?:\.\d+)?)\s*([KCF])\s*$') {
        Write-Host "ОШИБКА: неверный ввод: '$arg'. Ожидается число и суффикс K, C или F" -ForegroundColor Red
        return
    }
    $num = [double]$matches[1]
    $unit = $matches[2]
    $k = To-Kelvin $num $unit
    if ($null -eq $k) { Write-Host "ОШИБКА: неизвестная единица $unit" -ForegroundColor Red; return }
    Write-Host ("{0}{1} = {2:N2} K = {3:N2} C = {4:N2} F" -f $num, $unit.ToUpper(), $k,
        (From-Kelvin $k "C"), (From-Kelvin $k "F"))
}

Write-Host "=== Конвертер температур ==="
Write-Host "Поддерживаемые единицы: K (Кельвин), C (Цельсий), F (Фаренгейт)"
Write-Host "Формат ввода: 100K, 100C или 100F"
Write-Host ""

if ($FileIn) {
    # Режим ввода из файла: Read-Host игнорирует перенаправленный stdin,
    # поэтому для автоматического прогона источник входа задаётся явно.
    Write-Host "--- Режим ввода из файла: $FileIn ---"
    foreach ($line in (Get-ConsoleLines $FileIn)) {
        if ($line -match '^(выход|exit|quit)$') { break }
        Convert-Value $line
    }
} elseif ($values.Count -eq 0) {
    Write-Host "--- Интерактивный режим, для выхода введите выход ---"
    while ($true) {
        $line = Read-Host "temp>"
        if ($line -match '^(выход|exit|quit)$') { Write-Host "Работа завершена."; break }
        Convert-Value $line
    }
} else {
    foreach ($v in $values) { Convert-Value $v }
}

