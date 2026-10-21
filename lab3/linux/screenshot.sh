#!/bin/bash
# Linux screenshot script для чистых скриншотов без UI автоматизации
# Использует grim + slurp (Wayland) или import (X11)

set -euo pipefail

EXE_PATH="${1:-}"
ARGS="${2:-}"
OUT_DIR="${3:-скрины}"
FILE_NAME="${4:-screenshot.png}"
WAIT_KEY="${5:-1}"  # 1 = ждать Enter, 0 = не ждать

# Создаём папку
mkdir -p "$OUT_DIR"

# Полный путь к исполняемому файлу
FULL_PATH="$(pwd)/$EXE_PATH"
if [[ ! -f "$FULL_PATH" ]]; then
    echo "Файл не найден: $FULL_PATH" >&2
    exit 1
fi

# Определяем дисплей и Wayland/X11
if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    USE_WAYLAND=1
else
    USE_WAYLAND=0
fi

# Запускаем программу в терминале
# Пробуем разные терминалы: konsole, gnome-terminal, kitty, alacritty, xterm
TERM_CMD=""
if command -v konsole >/dev/null 2>&1; then
    TERM_CMD="konsole --maximize -e"
elif command -v gnome-terminal >/dev/null 2>&1; then
    TERM_CMD="gnome-terminal --maximize --"
elif command -v kitty >/dev/null 2>&1; then
    TERM_CMD="kitty --startup-maximized -e"
elif command -v alacritty >/dev/null 2>&1; then
    TERM_CMD="alacritty -e"
elif command -v xterm >/dev/null 2>&1; then
    TERM_CMD="xterm -maximize -e"
else
    echo "Не найден подходящий терминал" >&2
    exit 1
fi

# Запускаем в фоне
$TERM_CMD "$FULL_PATH" $ARGS &
TERM_PID=$!

# Ждём появления окна
sleep 1

# Получаем PID терминала (может быть не $TERM_PID если терминал форкается)
# Для Wayland используем grim + slurp для выделения окна
# Для X11 используем import

if [[ "$WAIT_KEY" == "1" ]]; then
    echo "Программа запущена. Нажмите Enter для скриншота..."
    read -r
fi

OUT_FILE="$(pwd)/$OUT_DIR/$FILE_NAME"

if [[ $USE_WAYLAND -eq 1 ]] && command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1; then
    # Wayland: grim + slurp - пользователь выделяет область мышкой
    # Для автоматизации можно использовать grimshot или найти окно по PID
    echo "Выделите область окна мышкой..."
    grim -g "$(slurp)" "$OUT_FILE"
elif command -v import >/dev/null 2>&1; then
    # X11: import -window root (весь экран) или -window <id>
    # Используем xdotool для поиска окна по PID
    if command -v xdotool >/dev/null 2>&1; then
        WIN_ID=$(xdotool search --pid $TERM_PID 2>/dev/null | head -1)
        if [[ -n "$WIN_ID" ]]; then
            import -window "$WIN_ID" "$OUT_FILE"
        else
            import -window root "$OUT_FILE"
        fi
    else
        import -window root "$OUT_FILE"
    fi
elif command -v gnome-screenshot >/dev/null 2>&1; then
    gnome-screenshot -w -f "$OUT_FILE"
elif command -v spectacle >/dev/null 2>&1; then
    spectacle -b -r -o "$OUT_FILE"
else
    echo "Не найден инструмент для скриншотов (grim/slurp, import, gnome-screenshot, spectacle)" >&2
    exit 1
fi

echo "Скриншот сохранён: $OUT_FILE"

# Ждём завершения терминала
wait $TERM_PID 2>/dev/null || true