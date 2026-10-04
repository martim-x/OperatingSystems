#!/bin/bash
# start_driver.sh — запускает драйвер в отдельном окне Konsole (через XWayland).
# Нужен потому, что консоль на Wayland из SSH падает, а на X11-мосте работает.
export XDG_RUNTIME_DIR=/run/user/1001
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus
export DISPLAY=:1
XAUTH=$(ls -t /run/user/1001/xauth_* 2>/dev/null | head -1)
export XAUTHORITY="$XAUTH"

pkill -f "lab2_sync/driver.sh" 2>/dev/null
sleep 1

rm -f "$HOME/lab2_sync/queue"/*.cmd "$HOME/lab2_sync/go" "$HOME/lab2_sync/done"/* 2>/dev/null

setsid env QT_QPA_PLATFORM=xcb LANG=C.UTF-8 \
    konsole --profile lab --separate --hold -e bash ~/lab2_sync/driver.sh \
    >/dev/null 2>&1 &

sleep 5
if pgrep -f "lab2_sync/driver.sh" >/dev/null; then
    echo "драйвер запущен"
else
    echo "драйвер НЕ запущен"
    exit 1
fi