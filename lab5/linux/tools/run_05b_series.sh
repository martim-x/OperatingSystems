#!/bin/bash
# Серия Lab-05b: P1=маска, P2/P3=nice двух дочерних процессов, TAG=метка серии.
# Кадры: a_params (до нагрузки), b_early, c_ps, d_mid, e_first, f_second (если второй жив), g_finish.

set -u

P1=${1:-}
P2=${2:-}
P3=${3:-}
TAG=${4:-s1}

if [ -z "$P1" ] || [ -z "$P2" ] || [ -z "$P3" ]; then
    echo "Использование: $0 P1 P2 P3 TAG" >&2
    exit 2
fi

DIR="$HOME/lab5_sync"
OUT="$DIR/logs"
SERIES_TTY=${SERIES_TTY:-/dev/tty}
SERIES_SHOTS=${SERIES_SHOTS:-$DIR/shots}
export SERIES_TTY SERIES_SHOTS

mkdir -p "$OUT" "$SERIES_SHOTS"
cd "$HOME/OS5" || exit 1
# shellcheck source=/dev/null
. "$(dirname "$0")/series_lib.sh"

run_series 05b "$TAG" "$P1" "$P2" "$P3"
