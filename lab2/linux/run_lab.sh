#!/bin/bash
# run_lab.sh — драйвер прогона ЛР2: выполняет команды в этом окне консоли
# и САМ снимает экран после каждой.
#
# Запуск:
#   konsole --fullscreen --hold -e bash ~/lab2_sync/run_lab.sh
#
# Протокол (односторонний, без файла go — он и вызывал зависание):
#   оператор по SSH кладёт  queue/NN_имя.cmd   (одна строка — команда)
#                          и, опционально, queue/NN_имя.in (строки ввода)
#   драйвер: clear -> печатает промпт с командой -> выполняет -> spectacle
#            -> кладёт shots/NN_имя.png и метку done/NN.done

DIR="$HOME/lab2_sync"
Q="$DIR/queue"
D="$DIR/done"
S="$DIR/shots"
mkdir -p "$Q" "$D" "$S"
rm -f "$D"/*.done "$S"/*.png 2>/dev/null

echo "=== Драйвер ЛР2 ==="
echo "Ожидание команд в $Q"
echo "После каждой команды снимок экрана снимается автоматически."

while true; do
    f=$(find "$Q" -name "*.cmd" -type f 2>/dev/null | sort | head -1)
    if [ -z "$f" ]; then
        sleep 0.5
        continue
    fi

    base=$(basename "$f" .cmd)
    num="${base%%_*}"
    slug="${base#*_}"
    cmd=$(cat "$f")
    infile="$Q/$base.in"

    clear

    # Сначала выполняем, потом печатаем промпт и вывод. Обратный порядок не годится:
    # часть скриптов (top5.sh) делает clear и затирает строку с командой.
    # Вывод собираем без escape-последовательностей: его \033[2J стёр бы
    # уже напечатанную строку команды.
    if [ -f "$infile" ]; then
        out=$(printf '%s\n' "$(cat "$infile")" | eval "$cmd" 2>&1 | sed -r 's/\x1B\[[0-9;?]*[a-zA-Z]//g; s/\x1B[()][A-Z0-9]//g; s/\r//g')
    else
        out=$(eval "$cmd" 2>&1 | sed -r 's/\x1B\[[0-9;?]*[a-zA-Z]//g; s/\x1B[()][A-Z0-9]//g; s/\r//g')
    fi

    echo -e "\033[1;32m[User-6d4ec851@archlab2 OS2]\033[0m \\\$ $cmd"
    if [ -f "$infile" ]; then
        while IFS= read -r line; do echo "$line"; done < "$infile"
    fi
    echo
    echo "$out"
    echo

    {
        echo "### КОМАНДА: $cmd"
        [ -f "$infile" ] && echo "### ВВОД: $(tr '\n' '|' < "$infile")"
        echo "$out"
    } > "$D/$num.txt"

    # ждём отрисовки кадра и снимаем экран
    sleep 1.5
    spectacle -b -n -f -o "$S/${num}_${slug}.png" >/dev/null 2>&1
    sleep 0.8
    rm -f "$f" "$infile"
    touch "$D/${num}.done"
done