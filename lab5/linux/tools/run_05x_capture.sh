#!/bin/bash
# Одиночный прогон Lab-05x со съёмкой: параметры до нагрузки, ранний вывод, середина, финал.

set -u

TAG=${1:-s1}
DIR="$HOME/lab5_sync"
OUT="$DIR/logs"
SERIES_TTY=${SERIES_TTY:-/dev/tty}
SERIES_SHOTS=${SERIES_SHOTS:-$DIR/shots}
export SERIES_TTY SERIES_SHOTS

mkdir -p "$OUT" "$SERIES_SHOTS"
cd "$HOME/OS5" || exit 1
# shellcheck source=/dev/null
. "$(dirname "$0")/series_lib.sh"

LOG="$OUT/05x.log"
rm -f "$LOG"
frame_log_init "$OUT/05x_${TAG}_frames.tsv"

tty_line "=== Lab-05x: 1 000 000 итераций, задержка 50 мс активным ожиданием каждые 1000 итераций ==="
tty_line "\$ ./Lab-05x"
shot "05x_${TAG}_a_params"

T0=$(mono)
./Lab-05x > >(tee "$LOG" > "$SERIES_TTY") 2>&1 &
PID=$!

sleep 0.8
shot "05x_${TAG}_b_early"
sleep 19
shot "05x_${TAG}_c_mid"

RC=0
wait "$PID" || RC=$?
sleep 0.3
shot "05x_${TAG}_d_finish"
T1=$(mono)

{
    printf -- '--- Lab-05x: сводка ---\n'
    printf 'Машина %s, CPU %s, старт uptime %s с, конец %s с, длительность %s с\n' \
        "$(uname -srm)" "$(nproc)" "$T0" "$T1" \
        "$(awk -v a="$T0" -v b="$T1" 'BEGIN{printf "%.1f", b-a}')"
    printf 'PID %s, код возврата %s\n' "$PID" "$RC"
    printf -- '--- первая строка и итог ---\n'
    head -1 "$LOG"
    tail -1 "$LOG"
    printf -- '--- кадры (имя, время снятия, SHA-256) ---\n'
    while IFS=$'\t' read -r _ f t0 t1; do
        printf '  %s\t%s\t%s\n' "$f" "$t0" "$(sha256sum "$SERIES_SHOTS/$f.png" 2>/dev/null | cut -c1-16)"
    done < "$FRAME_LOG"
} > "$OUT/05x_${TAG}_summary.txt" 2>&1
cat "$OUT/05x_${TAG}_summary.txt" > "$SERIES_TTY"
