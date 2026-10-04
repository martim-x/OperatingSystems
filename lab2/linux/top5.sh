#!/bin/bash
# top5.sh — монитор топ-5 процессов по CPU и памяти (уровень 9)
# Использование: ./top5.sh [интервал_в_секундах]   (по умолчанию 5)
# Работает в бесконечном цикле до Ctrl+C.

INTERVAL="${1:-5}"

if ! [[ $INTERVAL =~ ^[0-9]+$ ]] || [ "$INTERVAL" -eq 0 ]; then
    echo "Ошибка: интервал должен быть положительным целым числом секунд"
    exit 1
fi

trap 'echo; echo "Монитор остановлен."; exit 0' INT TERM

# Итоговая память системы в МБ — для перевода процентов в мегабайты
TOTAL_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)

fmt_row() {
    printf "%-8s %-24s %8s %10s %8s\n" "$1" "$2" "$3" "$4" "$5"
}

while true; do
    clear
    echo "================================================================"
    echo " МОНИТОР ПРОЦЕССОВ - ТОП-5"
    echo " Время:        $(date '+%Y-%m-%d %H:%M:%S')"
    echo " Интервал:     ${INTERVAL} с (Ctrl+C - выход)"
    echo " Всего памяти: ${TOTAL_MB} МБ"
    echo "================================================================"

    echo
    echo " ТОП-5 ПРОЦЕССОВ ПО ЗАГРУЗКЕ ЦП"
    fmt_row "PID" "ИМЯ" "CPU,%" "ПАМЯТЬ,МБ" "ВРЕМЯ CPU"
    fmt_row "--------" "------------------------" "--------" "---------" "----------"
    ps -eo pid,comm,%cpu,%mem,time --sort=-%cpu 2>/dev/null | head -6 | tail -5 | while read pid comm cpu mem cputime; do
        mbm=$(awk -v p="$mem" -v t="$TOTAL_MB" 'BEGIN{printf "%.1f", p*t/100}')
        printf "%-8s %-24s %8s %10s %8s\n" "$pid" "$comm" "$cpu" "$mbm" "$cputime"
    done

    echo
    echo " ТОП-5 ПРОЦЕССОВ ПО ЗАГРУЗКЕ ОПЕРАТИВНОЙ ПАМЯТИ"
    fmt_row "PID" "ИМЯ" "CPU,%" "ПАМЯТЬ,МБ" "ВРЕМЯ CPU"
    fmt_row "--------" "------------------------" "--------" "---------" "----------"
    ps -eo pid,comm,%cpu,%mem,time --sort=-%mem 2>/dev/null | head -6 | tail -5 | while read pid comm cpu mem cputime; do
        mbm=$(awk -v p="$mem" -v t="$TOTAL_MB" 'BEGIN{printf "%.1f", p*t/100}')
        printf "%-8s %-24s %8s %10s %8s\n" "$pid" "$comm" "$cpu" "$mbm" "$cputime"
    done

    echo
    echo "================================================================"
    sleep "$INTERVAL"
done