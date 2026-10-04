#!/bin/bash
# path_count.sh — подсчёт исполняемых и неисполняемых команд в PATH (уровень 8)

echo "============================================================"
echo " СТАТИСТИКА ПО КАТАЛОГАМ PATH"
echo "============================================================"
printf "%-50s %8s %8s\n" "КАТАЛОГ" "EXEC" "NON-EXEC"
printf "%-50s %8s %8s\n" "--------------------------------------------------" "--------" "--------"

total_exec=0
total_nonexec=0
missing=0

IFS=':' read -ra dirs <<< "$PATH"

for d in "${dirs[@]}"; do
    if [ -d "$d" ]; then
        e=$(find "$d" -maxdepth 1 -type f -executable 2>/dev/null | wc -l)
        ne=$(find "$d" -maxdepth 1 -type f ! -executable 2>/dev/null | wc -l)
        total_exec=$((total_exec + e))
        total_nonexec=$((total_nonexec + ne))
        printf "%-50s %8d %8d\n" "$d" "$e" "$ne"
    else
        missing=$((missing + 1))
        printf "%-50s %8s %8s\n" "$d" "-" "-"
    fi
done

echo "============================================================"
printf "Каталогов в PATH:              %d (из них не существует: %d)\n" "${#dirs[@]}" "$missing"
printf "Всего исполняемых файлов:      %d\n" "$total_exec"
printf "Всего неисполняемых файлов:    %d\n" "$total_nonexec"
printf "Всего файлов в PATH:           %d\n" "$((total_exec + total_nonexec))"
echo "============================================================"