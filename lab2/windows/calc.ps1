# calc.ps1 - калькулятор (уровень 8, PowerShell)
# Поддерживаемые операции: + - * /, остаток %, степень ^,
# корень sqrt a и root a b, sin cos tan (градусы),
# десятичный log10 и натуральный ln.
#
# Разбор выражения идёт по правилам приоритета: сначала ^ ,
# затем * / % , затем + - . Один общий шаблон на всё выражение
# не работал: он не разбирал 2+3*4 и путал номер группы
# named-capture с номером оператора, из-за чего 10/0 падал
# с ошибкой преобразования типа.
# Выражения передаются обычными аргументами ($args), а не через параметр
# с ValueFromRemainingArguments: такой параметр перехватывал и сам путь,
# из-за чего calc.ps1 2+3*4 пытался читать файл с именем "2+3*4".
# -FileIn - файл с выражениями, по одному в строке. Нужен для автоматического
# прогона: Read-Host игнорирует перенаправленный stdin и блокируется.

$ErrorActionPreference = "Continue"

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

function Show-Help {
    Write-Host "=== Калькулятор: поддерживаемые операции ==="
    Write-Host "  a+b, a-b, a*b, a/b        базовая арифметика"
    Write-Host "  a%b                      остаток от деления"
    Write-Host "  a^b                      возведение в степень"
    Write-Host "  root a b                 корень b-й степени из a"
    Write-Host "  sin a, cos a, tan a      тригонометрия (градусы)"
    Write-Host "  log10 a, ln a            десятичный и натуральный логарифмы"
    Write-Host "  sqrt a                   квадратный корень"
    Write-Host ""
    Write-Host "  Примеры: 2+3*4   root 27 3   sin 30   log10 100   10%3"
}

# Базовое число с необязательным знаком. Культура фиксирована,
# иначе на машине с запятой в качестве разделителя Parse бросает исключение.
function Get-Number([string]$t) {
    $t = $t.Trim()
    if ($t -notmatch '^[+-]?[0-9]+(\.[0-9]+)?$') { return $null }
    return [double]::Parse($t, [Globalization.CultureInfo]::InvariantCulture)
}

# Ошибку передаём через скриптовую переменную, а не через throw:
# throw прервал бы весь пакет и следующие выражения не считались бы.
$script:Err = $null

# Уровень 1: сложение и вычитание - низший приоритет, левоассоциативно.
function Eval-Sum([string]$e) {
    $m = [regex]::Match($e, '^(.+?)\s*([+-])\s*(.+)$')
    if ($m.Success -and $m.Groups[1].Value -match '[0-9)]') {
        $l = Eval-Product $m.Groups[1].Value
        if ($null -eq $l) { return $null }
        $r = Eval-Product $m.Groups[3].Value
        if ($null -eq $r) { return $null }
        if ($m.Groups[2].Value -eq '+') { return $l + $r }
        return $l - $r
    }
    return Eval-Product $e
}

# Уровень 2: умножение, деление, остаток от деления.
function Eval-Product([string]$e) {
    $m = [regex]::Match($e, '^(.+?)\s*([*/%])\s*(.+)$')
    if ($m.Success -and $m.Groups[1].Value -match '[0-9)]') {
        $l = Eval-Power $m.Groups[1].Value
        if ($null -eq $l) { return $null }
        $r = Eval-Power $m.Groups[3].Value
        if ($null -eq $r) { return $null }
        switch ($m.Groups[2].Value) {
            "*" { return $l * $r }
            "/" {
                if ($r -eq 0) { $script:Err = "деление на ноль невозможно"; return $null }
                return $l / $r
            }
            default {
                if ($r -eq 0) { $script:Err = "остаток от деления на ноль невозможен"; return $null }
                return $l - [math]::Floor($l / $r) * $r
            }
        }
    }
    return Eval-Power $e
}

# Уровень 3: возведение в степень - правоассоциативно.
function Eval-Power([string]$e) {
    $m = [regex]::Match($e, '^(.+?)\s*\^\s*(.+)$')
    if ($m.Success) {
        $l = Get-Number $m.Groups[1].Value
        if ($null -eq $l) { return $null }
        $r = Eval-Power $m.Groups[2].Value
        if ($null -eq $r) { return $null }
        return [math]::Pow($l, $r)
    }
    return Get-Number $e
}

# Форматирование числа: запятая как десятичный разделитель ломает
# последующий разбор выражения, поэтому печатаем точкой.
function Fmt([double]$v) {
    # Печатаем точкой (инвариантная культура), без хвостовых нулей:
    # запятая сломала бы последующий разбор выражения, а нули не нужны.
    $s = $v.ToString("F10", [System.Globalization.CultureInfo]::InvariantCulture)
    if ($s.Contains(".")) { $s = $s.TrimEnd("0").TrimEnd(".") }
    return $s
}

function Invoke-Calc([string]$line) {
    $e = $line.Trim()
    if ($e -eq "") { return }
    $script:Err = $null

    if ($e -match '^\s*root\s+(\S+)\s+(\S+)\s*$') {
        $a = Get-Number $matches[1]; $n = Get-Number $matches[2]
        if ($null -eq $a -or $null -eq $n) { Write-Host "ОШИБКА: не удалось разобрать выражение: $e" -ForegroundColor Red; return }
        if ($n -eq 0) { Write-Host "ОШИБКА: показатель корня не может быть нулём" -ForegroundColor Red; return }
        Write-Host ("{0} = {1}" -f $e, ((Fmt ([math]::Pow($a, 1.0 / $n)))))
        return
    }
    if ($e -match '^\s*(sin|cos|tan)\s+(\S+)\s*$') {
        $fn = $matches[1]; $deg = Get-Number $matches[2]
        if ($null -eq $deg) { Write-Host "ОШИБКА: не удалось разобрать выражение: $e" -ForegroundColor Red; return }
        $rad = $deg * [math]::PI / 180
        $v = switch ($fn) {
            "sin" { [math]::Sin($rad) }
            "cos" { [math]::Cos($rad) }
            "tan" { [math]::Tan($rad) }
        }
        Write-Host ("{0} = {1}" -f $e, (Fmt $v))
        return
    }
    if ($e -match '^\s*log10\s+(\S+)\s*$') {
        $a = Get-Number $matches[1]
        if ($null -eq $a) { Write-Host "ОШИБКА: не удалось разобрать выражение: $e" -ForegroundColor Red; return }
        if ($a -le 0) { Write-Host "ОШИБКА: аргумент логарифма должен быть больше нуля" -ForegroundColor Red; return }
        Write-Host ("{0} = {1}" -f $e, ((Fmt ([math]::Log10($a)))))
        return
    }
    if ($e -match '^\s*ln\s+(\S+)\s*$') {
        $a = Get-Number $matches[1]
        if ($null -eq $a) { Write-Host "ОШИБКА: не удалось разобрать выражение: $e" -ForegroundColor Red; return }
        if ($a -le 0) { Write-Host "ОШИБКА: аргумент логарифма должен быть больше нуля" -ForegroundColor Red; return }
        Write-Host ("{0} = {1}" -f $e, ((Fmt ([math]::Log($a)))))
        return
    }
    if ($e -match '^\s*sqrt\s+(\S+)\s*$') {
        $a = Get-Number $matches[1]
        if ($null -eq $a) { Write-Host "ОШИБКА: не удалось разобрать выражение: $e" -ForegroundColor Red; return }
        if ($a -lt 0) { Write-Host "ОШИБКА: подкоренное выражение не может быть отрицательным" -ForegroundColor Red; return }
        Write-Host ("{0} = {1}" -f $e, ((Fmt ([math]::Sqrt($a)))))
        return
    }

    $v = Eval-Sum $e
    if ($script:Err) {
        Write-Host ("ОШИБКА: {0} ({1})" -f $script:Err, $e) -ForegroundColor Red
    } elseif ($null -eq $v) {
        Write-Host "ОШИБКА: не удалось разобрать выражение: $e" -ForegroundColor Red
    } else {
        Write-Host ("{0} = {1}" -f $e, (Fmt $v))
    }
}

Write-Host "=== Калькулятор ==="
Show-Help

# Разбор аргументов вручную: объявленный параметр [string]$FileIn
# получал первый позиционный аргумент, и "calc.ps1 2+3*4" пытался
# прочитать файл с именем "2+3*4".
# Ключ -Help печатает справку и завершает работу: без него запуск без
# аргументов уходил в интерактивный режим и намертво блокировал драйвер.
$FileIn = $null
$WantHelp = $false
$Exprs = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '-FileIn') {
        $i++
        if ($i -lt $args.Count) { $FileIn = $args[$i] }
    } elseif ($args[$i] -eq '-Help') {
        $WantHelp = $true
    } else {
        $Exprs += $args[$i]
    }
}

if ($WantHelp) {
    Write-Host ""
    Write-Host "--- Справка по ключам ---"
    Write-Host "  -Help        показать эту справку и выйти"
    Write-Host "  -FileIn путь читать выражения из файла, по одному в строке"
    Write-Host "  выражения    например: calc.ps1 2+3*4 sqrt 16"
    exit 0
}

if ($FileIn) {
    Write-Host ""
    Write-Host "--- Режим ввода из файла: $FileIn ---"
    foreach ($line in (Get-ConsoleLines $FileIn)) {
        if ($line -match '^(выход|exit|quit)$') { break }
        Invoke-Calc $line
    }
} elseif ($Exprs.Count -eq 0) {
    Write-Host ""
    Write-Host "--- Интерактивный режим, для выхода введите выход ---"
    while ($true) {
        $line = Read-Host "calc>"
        if ($line -match '^(выход|exit|quit)$') { Write-Host "Работа завершена."; break }
        Invoke-Calc $line
    }
} else {
    Write-Host ""
    # "sqrt 16" из командной строки приходит двумя аргументами,
    # поэтому склеиваем функцию с её операндом в одно выражение.
    $joined = @()
    for ($i = 0; $i -lt $Exprs.Count; $i++) {
        if ($Exprs[$i] -match '^(root|sin|cos|tan|log10|ln|sqrt)$' -and
            $i + 1 -lt $Exprs.Count) {
            $pair = $Exprs[$i] + ' ' + $Exprs[$i + 1]
            $joined += $pair
            $i++
            if ($Exprs[$i] -ne '' -and $Exprs[$i] -notmatch '^[0-9.+-]' -and
                $i + 1 -lt $Exprs.Count -and $pair -match '^root ') {
                $joined[-1] = $pair + ' ' + $Exprs[$i + 1]
                $i++
            }
        } else {
            $joined += $Exprs[$i]
        }
    }
    foreach ($e in $joined) { Invoke-Calc $e }
}