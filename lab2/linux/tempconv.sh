#!/bin/bash
# tempconv.sh — конвертер температур (уровень 8, аналог tempconv.ps1)
# Формат ввода: <число>[K|C|F]   по умолчанию C; 100C, 273.15K, 212F, 25

echo "=== ТЕМПЕРАТУРНЫЙ КОНВЕРТЕР ==="
echo "Введите температуру в виде: 100C, 273K, 212F, 25 (без суффикса = Цельсий)"
echo "Выход: q"

while true; do
    read -r -p "Введите температуру: " raw
    raw=$(echo "$raw" | tr -d ' ' | tr 'a-zq' 'A-ZQ')

    [[ -z $raw ]] && continue
    [[ $raw == "Q" || $raw == "Й" ]] && break

    # Разбор: число + необязательный суффикс единицы
    if [[ $raw =~ ^([+-]?[0-9]+([.][0-9]+)?)([KCF])?$ ]]; then
        value=${BASH_REMATCH[1]}
        unit=${BASH_REMATCH[3]:-C}

        case $unit in
            C) c=$value ; k=$(awk -v c="$c" 'BEGIN{print c+273.15}') ; f=$(awk -v c="$c" 'BEGIN{print c*9/5+32}') ;;
            K) k=$value ; c=$(awk -v k="$k" 'BEGIN{print k-273.15}') ; f=$(awk -v c="$c" 'BEGIN{print c*9/5+32}') ;;
            F) f=$value ; c=$(awk -v f="$f" 'BEGIN{print (f-32)*5/9}') ; k=$(awk -v c="$c" 'BEGIN{print c+273.15}') ;;
        esac

        printf "Введено:      %s %s\n" "$value" "$unit"
        printf "Цельсий:      %.2f C\n" "$(awk -v x="$c" 'BEGIN{print x}')"
        printf "Кельвин:      %.2f K\n" "$(awk -v x="$k" 'BEGIN{print x}')"
        printf "Фаренгейт:    %.2f F\n" "$(awk -v x="$f" 'BEGIN{print x}')"
        echo "----------------------------------------"
    else
        echo "Ошибка: неверный ввод. Ожидается число и необязательный суффикс K, C или F."
    fi
done

echo "Конвертер завершён."