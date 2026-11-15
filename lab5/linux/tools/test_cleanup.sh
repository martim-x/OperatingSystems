#!/bin/bash
# Проверка L5-LNX-09: очистка привязана к PID прогона и не трогает параллельный экземпляр.
# Запускает два независимых Lab-05b, останавливает только первый и проверяет, что второй жив.

set -u

cd "$HOME/OS5" || exit 1
SERIES_TTY=${SERIES_TTY:-/dev/stdout}
SERIES_SHOTS=${SERIES_SHOTS:-$HOME/lab5_sync/shots}
export SERIES_TTY SERIES_SHOTS
# shellcheck source=/dev/null
. "$(dirname "$0")/series_lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

LAB05_ITERATIONS=400000 ./Lab-05b 0 0 0 > "$TMP/run1.log" 2>&1 &
P1=$!
LAB05_ITERATIONS=400000 ./Lab-05b 0 0 0 > "$TMP/run2.log" 2>&1 &
P2=$!

sleep 1.5
mapfile -t K1 < <(pgrep -P "$P1" -x Lab-05x)
mapfile -t K2 < <(pgrep -P "$P2" -x Lab-05x)

tty_line "run1: родитель $P1, дети ${K1[*]:-нет}"
tty_line "run2: родитель $P2, дети ${K2[*]:-нет}"

stop_run "$P1" Lab-05b Lab-05x "${K1[@]}" "$P1"
sleep 1

fail=0
c1_kids=0
c1_parent=0
c2_kids=0
c2_parent=0
for p in "${K1[@]}"; do pid_alive "$p" && c1_kids=1; done
pid_alive "$P1" && c1_parent=1
for p in "${K2[@]}"; do pid_alive "$p" && c2_kids=1; done
pid_alive "$P2" && c2_parent=1

tty_line "после остановки run1: родитель run1 жив=$c1_parent, дети run1 живы=$c1_kids"
tty_line "после остановки run1: родитель run2 жив=$c2_parent, дети run2 живы=$c2_kids"

[ "$c1_parent" -eq 0 ] || { tty_line "ПРОВАЛ: родитель первого прогона не остановлен"; fail=1; }
[ "$c1_kids" -eq 0 ] || { tty_line "ПРОВАЛ: остались дочерние процессы первого прогона"; fail=1; }
[ "$c2_parent" -eq 1 ] || { tty_line "ПРОВАЛ: остановлен родитель второго прогона"; fail=1; }
[ "$c2_kids" -eq 1 ] || { tty_line "ПРОВАЛ: остановлены дочерние процессы второго прогона"; fail=1; }

stop_run "$P2" Lab-05b Lab-05x "${K2[@]}" "$P2"
wait 2>/dev/null

if [ "$fail" -eq 0 ]; then
    tty_line "ИТОГ: очистка PID-ограниченная, параллельный прогон не затронут"
    exit 0
fi
tty_line "ИТОГ: проверка не пройдена"
exit 1
