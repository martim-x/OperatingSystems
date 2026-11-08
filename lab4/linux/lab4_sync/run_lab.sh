#!/bin/bash

DIR="$HOME/lab4_sync"
Q="$DIR/queue"
D="$DIR/done"
S="$DIR/shots"
WORK="$HOME/OS4"
mkdir -p "$Q" "$D" "$S" "$WORK"
rm -f "$D"/*.done "$S"/*.png 2>/dev/null

cd "$WORK" || exit 1

echo "=== Драйвер ЛР4 (управление потоками) ==="
echo "Рабочий каталог: $WORK"
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

    if [ -f "$infile" ]; then
        out=$(printf "%s\n" "$(cat "$infile")" | eval "$cmd" 2>&1 | sed -r "s/\x1B\[[0-9;?]*[a-zA-Z]//g; s/\x1B[()][A-Z0-9]//g; s/\r//g")
    else
        out=$(eval "$cmd" 2>&1 | sed -r "s/\x1B\[[0-9;?]*[a-zA-Z]//g; s/\x1B[()][A-Z0-9]//g; s/\r//g")
    fi

    printf '\033[1;32m[User-6d4ec851@archlab4 OS4]\033[0m $ %s\n' "$cmd"
    if [ -f "$infile" ]; then
        while IFS= read -r line; do echo "$line"; done < "$infile"
    fi
    echo
    echo "$out"
    echo

    {
        echo "### КОМАНДА: $cmd"
        [ -f "$infile" ] && echo "### ВВОД: $(tr "\n" "|" < "$infile")"
        echo "$out"
    } > "$D/$num.txt"

    sleep 1.5
    spectacle -b -n -f -o "$S/${num}_${slug}.png" >/dev/null 2>&1
    sleep 0.8
    rm -f "$f" "$infile"
    touch "$D/${num}.done"
done
