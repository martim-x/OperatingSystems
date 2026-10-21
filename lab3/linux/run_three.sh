#!/bin/bash
# Linux script для запуска 3 процессов одновременно и скриншота

set -euo pipefail

MODE="${1:-lab03a}"  # lab03a или 3x
OUT_DIR="${2:-скрины/уровень_4-5}"
FILE_NAME="${3:-task11_three_proc.png}"

mkdir -p "$OUT_DIR"

if [[ "$MODE" == "lab03a" ]]; then
    # Запускаем Lab-03a который создаёт 2 дочерних
    ./build/Lab-03a 3 &
    MAIN_PID=$!
    echo "Запущен Lab-03a (PID=$MAIN_PID)"
else
    # Запускаем 3 копии Lab-03x
    for i in {1..3}; do
        ./build/Lab-03x 10 &
        echo "Запущен Lab-03x #$i (PID=$!)"
    done
fi

# Ждём появления окон
sleep 1.5

# Определяем Wayland/X11
if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    USE_WAYLAND=1
else
    USE_WAYLAND=0
fi

echo "Нажмите Enter для скриншота..."
read -r

OUT_FILE="$(pwd)/$OUT_DIR/$FILE_NAME"

if [[ $USE_WAYLAND -eq 1 ]] && command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1; then
    echo "Выделите область экрана мышкой..."
    grim -g "$(slurp)" "$OUT_FILE"
elif command -v import >/dev/null 2>&1; then
    import -window root "$OUT_FILE"
elif command -v gnome-screenshot >/dev/null 2>&1; then
    gnome-screenshot -f "$OUT_FILE"
elif command -v spectacle >/dev/null 2>&1; then
    spectacle -b -f -o "$OUT_FILE"
else
    echo "Нет инструмента для скриншотов" >&2
    exit 1
fi

echo "Скриншот сохранён: $OUT_FILE"

# Убиваем процессы
if [[ "$MODE" == "lab03a" ]]; then
    kill $MAIN_PID 2>/dev/null || true
    sleep 0.5
    pkill -P $MAIN_PID 2>/dev/null || true
else
    pkill -f "Lab-03x" 2>/dev/null || true
fi