#!/bin/bash
# driver.sh — посредник для съёмки скриншотов «1 команда = 1 снимок».
#
# Работает в окне Konsole (видимом на экране). Протокол:
#   - читает очередь команд из ~/lab2_sync/queue/
#   - для каждой команды: clear, печатает её как в консоли, выполняет, ждёт сигнала
#   - сигнал: файл ~/lab2_sync/go (создаёт оператор = я, по SSH)
#   - отчёт о выполнении: ~/lab2_sync/done/<номер> с выводом
#
# ВАЖНО: этот скрипт запускается ВНУТРИ окна консоли, а оператор — по SSH.

DIR="$HOME/lab2_sync"
Q="$DIR/queue"
D="$DIR/done"
GO="$DIR/go"
mkdir -p "$Q" "$D"

echo "=== Драйвер ЛР2 готов ==="
echo "Ожидание команд в $Q"

while true; do
    # ждём файл команды
    f=$(find "$Q" -name "*.cmd" -type f 2>/dev/null | sort | head -1)
    if [ -z "$f" ]; then
        sleep 0.4
        continue
    fi

    base=$(basename "$f" .cmd)
    num="${base%%_*}"
    title="${base#*_}"
    cmd=$(cat "$f")
    rm -f "$f"

    # очищаем экран и печатаем команду как настоящий промпт
    clear
    echo -e "\033[1;32m[User-6d4ec851@archlab2 ~\033[0m \$ $cmd"
    echo

    # выполняем и пишем вывод
    out=$(eval "$cmd" 2>&1)
    echo "$out"
    echo

    # сохраняем полный текст кадра (для отчёта и проверки)
    {
        echo "### КОМАНДА: $cmd"
        echo "$out"
    } > "$D/$num.txt"

    # сообщаем оператору: кадр готов к съёмке
    echo "$num" > "$D/$num.ready"

    # ждём разрешения оператора снять скриншот
    while [ ! -f "$GO" ]; do sleep 0.3; done
    rm -f "$GO"

    echo "$num" > "$D/$num.shot"
    sleep 0.5
done