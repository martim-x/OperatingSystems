#!/bin/bash
# bat_04.sh — аналог bat_04.bat: a-b, a+b, c/b, c*b, (a-b)*(b-a)
# a, b, c — первый, второй и третий параметры. Проверка деления на ноль.

if [ $# -ne 3 ]; then
    echo "Использование: $0 <a> <b> <c>"
    exit 1
fi

a=$1
b=$2
c=$3

echo "=== bat_04: арифметика ==="
echo "a=$a  b=$b  c=$c"
echo "a-b = $(( a - b ))"
echo "a+b = $(( a + b ))"

if [ "$b" -eq 0 ]; then
    echo "c/b — ОШИБКА: деление на ноль невозможно"
    exit 1
fi

echo "c/b = $(( c / b ))"
echo "c*b = $(( c * b ))"
echo "(a-b)*(b-a) = $(( (a - b) * (b - a) ))"
