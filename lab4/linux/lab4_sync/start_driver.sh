#!/bin/bash

export XDG_RUNTIME_DIR=/run/user/1001
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus
export DISPLAY=:1
XAUTH=$(ls -t /run/user/1001/xauth_* 2>/dev/null | head -1)
export XAUTHORITY="$XAUTH"

pkill -f "lab4_sync/run_lab.sh" 2>/dev/null
sleep 1

rm -f "$HOME/lab4_sync/queue"/*.cmd "$HOME/lab4_sync/done"/* 2>/dev/null

setsid env QT_QPA_PLATFORM=xcb LANG=C.UTF-8 \
    konsole --profile lab --separate --hold -e bash ~/lab4_sync/run_lab.sh \
    >/dev/null 2>&1 &

sleep 5
if pgrep -f "lab4_sync/run_lab.sh" >/dev/null; then
    echo "драйвер ЛР4 запущен"
else
    echo "драйвер ЛР4 НЕ запущен"
    exit 1
fi
