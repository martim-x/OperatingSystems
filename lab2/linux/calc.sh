#!/bin/bash
# calc.sh — интерактивный калькулятор (уровень 8, аналог calc.ps1)
# Операции: + - * / % ^ (степень) root (корень n-й степени) sin cos tan log ln

show_help() {
    cat <<'EOF'
=== КАЛЬКУЛЯТОР ===
Бинарные:  <число> <оп> <число>   где op = + - * / % ^ root
Унарные:   <функция> <число>       где функция = sin cos tan log ln sqrt
Примеры:   2 + 3     |  2 ^ 10   |  27 root 3   |  sin 1.57   |  sqrt 16
Выход:     q
EOF
}

calc_unary() {
    local fn=$1 x=$2
    case $fn in
        sqrt) awk -v x="$x" 'BEGIN {print sqrt(x)}' ;;
        sin)  awk -v x="$x" 'BEGIN {print sin(x)}' ;;
        cos)  awk -v x="$x" 'BEGIN {print cos(x)}' ;;
        tan)  awk -v x="$x" 'BEGIN {print tan(x)}' ;;
        log)  awk -v x="$x" 'BEGIN { if (x<=0) exit 1; print log(x)/log(10) }' ;;
        ln)   awk -v x="$x" 'BEGIN { if (x<=0) exit 1; print log(x) }' ;;
        *) return 2 ;;
    esac
}

calc_binary() {
    local a=$1 op=$2 b=$3
    case $op in
        +) awk -v a="$a" -v b="$b" 'BEGIN {print a+b}' ;;
        -) awk -v a="$a" -v b="$b" 'BEGIN {print a-b}' ;;
        '*') awk -v a="$a" -v b="$b" 'BEGIN {print a*b}' ;;
        /) awk -v a="$a" -v b="$b" 'BEGIN { if (b==0) exit 1; print a/b }' ;;
        %) awk -v a="$a" -v b="$b" 'BEGIN { if (b==0) exit 1; printf "%.10g\n", (a-int(a/b)*b) }' ;;
        ^) awk -v a="$a" -v b="$b" 'BEGIN {print a^b}' ;;
        root) awk -v a="$a" -v b="$b" 'BEGIN { if (b==0) exit 1; print a^(1/b) }' ;;
        *) return 2 ;;
    esac
}

is_number() {
    [[ $1 =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

while true; do
    show_help
    read -r -p "Введите выражение: " line
    line=$(echo "$line" | tr 'A-Z' 'a-z')

    [[ -z $line ]] && continue
    [[ $line == "q" || $line == "выход" ]] && break

    read -r -a parts <<< "$line"

    if [[ ${#parts[@]} -eq 3 ]]; then
        if ! is_number "${parts[0]}" || ! is_number "${parts[2]}"; then
            echo "Ошибка: неверный ввод числа"; continue
        fi
        if [[ "${parts[1]}" == "/" || "${parts[1]}" == "%" || "${parts[1]}" == "root" ]] \
           && awk -v b="${parts[2]}" 'BEGIN {exit !(b==0)}'; then
            echo "Ошибка: деление на ноль"; continue
        fi
        result=$(calc_binary "${parts[0]}" "${parts[1]}" "${parts[2]}") \
            || { echo "Ошибка: недопустимая операция или деление на ноль"; continue; }
        printf "Результат: %s\n" "$result"

    elif [[ ${#parts[@]} -eq 2 ]]; then
        if ! is_number "${parts[1]}"; then
            echo "Ошибка: неверный ввод числа"; continue
        fi
        case ${parts[0]} in
            log|ln)
                if awk -v x="${parts[1]}" 'BEGIN {exit !(x<=0)}'; then
                    echo "Ошибка: аргумент логарифма должен быть > 0"; continue
                fi
                ;;
        esac
        result=$(calc_unary "${parts[0]}" "${parts[1]}") \
            || { echo "Ошибка: неизвестная функция"; continue; }
        printf "Результат: %s\n" "$result"
    else
        echo "Ошибка: неверный формат ввода"
    fi
done

echo "Калькулятор завершён."