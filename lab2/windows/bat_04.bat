@echo off
rem ============================================================
rem  bat_04 - вычисление a-b, a+b, c/b, c*b, (a-b)*(b-a),
rem  где a, b, c - первый, второй и третий параметры.
rem  Деление на ноль проверяется ДО вычисления: иначе set /a
rem  обрывает пакет сообщением об ошибке и следующие echo не
rem  выводятся вовсе.
rem ============================================================

setlocal enabledelayedexpansion

set /a a=%~1
set /a b=%~2
set /a c=%~3

if "%a%"=="" set /a a=1
if "%b%"=="" set /a b=1
if "%c%"=="" set /a c=1

echo === bat_04: арифметика ===
echo a=%a%  b=%b%  c=%c%

set /a diff=a-b
set /a sum=a+b
set /a prod=a*b
set /a cross=b-a
set /a expr=diff*cross

echo a-b = %diff%
echo a+b = %sum%
echo a*b = %prod%
echo (a-b)*(b-a) = %expr%

if %b%==0 (
    echo c/b = ОШИБКА: деление на ноль невозможно
) else (
    set /a quot=c/b
    echo c/b = !quot!
)

endlocal