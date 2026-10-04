#!/bin/bash
# batch.sh — прогон списка команд через драйвер: 1 команда = 1 снимок.
# Формат строки файла: <номер>;;<имя>;;<команда>
# Использование: bash batch.sh <файл_с_командами>

BATCH="$1"
ok=0; fail=0

while IFS=';;' read -r num name cmd; do
    [ -z "$num" ] && continue
    case "$num" in \#*) continue ;; esac

    if bash ~/lab2_sync/run_lab.sh "$num" "$name" "$cmd"; then
        ok=$((ok+1))
        echo "  [$num/$name] ок"
    else
        fail=$((fail+1))
        echo "  [$num/$name] ОШИБКА"
    fi
done < "$BATCH"

echo "=============================="
echo "Готово: успешно $ok, с ошибкой $fail"
echo "=============================="
