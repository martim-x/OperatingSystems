#!/bin/bash
# Общая часть съёмочных серий ЛР5.
# Кадр снимается spectacle (реальный GUI), метки времени — /proc/uptime (монотонные),
# завершение процессов — только по записанным PID текущего прогона (без pkill).

SERIES_TTY=${SERIES_TTY:-/dev/tty}
SERIES_SHOTS=${SERIES_SHOTS:-$HOME/lab5_sync/shots}
FRAME_LOG=${FRAME_LOG:-/dev/null}

mono() { cut -d' ' -f1 /proc/uptime; }

frame_log_init() {
    FRAME_LOG=$1
    : > "$FRAME_LOG"
}

shot() {
    local name=$1
    local out="$SERIES_SHOTS/$1.png"
    local t0 t1

    t0=$(mono)
    spectacle -b -n -f -o "$out" >/dev/null 2>&1
    t1=$(mono)
    printf 'FRAME\t%s\t%s\t%s\n' "$name" "$t0" "$t1" >> "$FRAME_LOG"
}

tty_line() { printf '%s\n' "$*" > "$SERIES_TTY"; }

pid_alive() {
    local st

    [ -r "/proc/$1/stat" ] || return 1
    st=$(awk '{print $3}' "/proc/$1/stat" 2>/dev/null)
    [ "$st" != "Z" ]
}

pid_comm() { sed -n 's/^[0-9]* (\(.*\)) .*/\1/p' "/proc/$1/stat" 2>/dev/null; }
pid_ppid() { awk '{print $4}' "/proc/$1/stat" 2>/dev/null; }

# stop_run <parent> <parent-comm> <child-comm> <child pid>...
# Завершает только PID, записанные для ЭТОГО прогона, и только после проверки
# comm/PPID. Глобальных pkill нет: параллельный прогон не затрагивается.
stop_run() {
    local parent=$1 pcomm=$2 ccomm=$3
    local p killed="" targets=()

    shift 3
    for p in "$@"; do
        [ -n "$p" ] || continue
        pid_alive "$p" || continue
        if [ "$p" = "$parent" ]; then
            if [ "$(pid_comm "$p")" != "$pcomm" ]; then
                tty_line "cleanup: PID $p имеет comm '$(pid_comm "$p")', ожидался '$pcomm' — пропуск"
                continue
            fi
        else
            if [ "$(pid_comm "$p")" != "$ccomm" ]; then
                tty_line "cleanup: PID $p имеет comm '$(pid_comm "$p")', ожидался '$ccomm' — пропуск"
                continue
            fi
            if [ "$(pid_ppid "$p")" != "$parent" ]; then
                tty_line "cleanup: PID $p не является потомком $parent — пропуск"
                continue
            fi
        fi
        targets+=("$p")
        kill -TERM "$p" 2>/dev/null && killed="$killed $p"
    done
    tty_line "cleanup: SIGTERM только для PID:${killed:- (нет)}"
    [ ${#targets[@]} -gt 0 ] || return 0
    sleep 1
    for p in "${targets[@]}"; do
        if pid_alive "$p"; then
            kill -KILL "$p" 2>/dev/null && tty_line "cleanup: PID $p не ответил на TERM, отправлен KILL"
        fi
    done
}

series_header() {
    local kind=$1 tag=$2 p1=$3 p2=$4 p3=$5
    local prog=$([ "$kind" = "05b" ] && echo "Lab-05b" || echo "Lab-05c")
    local unit=$([ "$kind" = "05b" ] && echo "процессы" || echo "потоки")

    tty_line "=== $prog, серия $tag: P1=$p1 P2=$p2 P3=$p3 ($unit) ==="
    tty_line "\$ ./$prog $p1 $p2 $p3"
}

# run_series <05b|05c> <tag> <P1> <P2> <P3>
run_series() {
    local kind=$1 tag=$2 p1=$3 p2=$4 p3=$5
    local prog=$([ "$kind" = "05b" ] && echo "Lab-05b" || echo "Lab-05c")
    local unit=$([ "$kind" = "05b" ] && echo "дочерних процессов" || echo "дочерних потоков")
    local LOG="$OUT/${kind}_${tag}.log"
    local SUM="$OUT/${kind}_${tag}_summary.txt"
    local MAXWAIT=${LAB05_MAX_WAIT:-240}

    rm -f "$LOG"
    frame_log_init "$OUT/${kind}_${tag}_frames.tsv"
    series_header "$kind" "$tag" "$p1" "$p2" "$p3"
    shot "${kind}_${tag}_a_params"

    local T0
    T0=$(mono)
    ./"$prog" "$p1" "$p2" "$p3" > >(tee "$LOG" > "$SERIES_TTY") 2>&1 &
    local PID=$!

    local A="" B=""
    for _ in $(seq 1 120); do
        if [ "$kind" = "05b" ]; then
            A=$(sed -n 's/.*Запущены дочерние процессы: PID \([0-9]*\).*/\1/p' "$LOG" 2>/dev/null | head -1)
            B=$(sed -n 's/.* и PID \([0-9]*\).*/\1/p' "$LOG" 2>/dev/null | head -1)
        else
            A=$(sed -n 's/^Поток 1: TID \([0-9]*\).*/\1/p' "$LOG" 2>/dev/null | head -1)
            B=$(sed -n 's/^Поток 2: TID \([0-9]*\).*/\1/p' "$LOG" 2>/dev/null | head -1)
        fi
        [ -n "$A" ] && [ -n "$B" ] && break
        sleep 0.05
    done
    if [ -z "$A" ] || [ -z "$B" ]; then
        tty_line "ВНИМАНИЕ: не удалось определить PID/TID участников из лога"
    fi
    tty_line "Родитель PID $PID, участники: $A и $B"

    alive() {
        local id=$1
        if [ "$kind" = "05b" ]; then
            pid_alive "$id"
        else
            [ -d "/proc/$PID/task/$id" ] && pid_alive "$id"
        fi
    }

    sleep 0.8
    shot "${kind}_${tag}_b_early"

    sleep 4
    {
        if [ "$kind" = "05b" ]; then
            printf -- '--- ps -L по процессам (PID, PPID, TID, NI, PSR, STAT) ---\n'
            ps -o pid,ppid,tid,ni,psr,stat,comm -L -p "$PID,$A,$B"
            local p
            for p in "$A" "$B"; do
                printf -- '--- /proc/%s/status ---\n' "$p"
                grep -E '^(Name|Pid|Tgid|CapEff|Cpus_allowed_list):' "/proc/$p/status"
                printf -- '--- /proc/%s/stat (поля 18,19) ---\n' "$p"
                awk '{printf "priority=%s nice=%s\n", $18, $19}' "/proc/$p/stat"
                printf -- '--- taskset %s ---\n' "$p"
                taskset -c -p "$p"
            done
        else
            printf -- '--- ps -L по процессу %s (TID, NI, PSR, STAT) ---\n' "$PID"
            ps -o pid,tid,ni,psr,stat,comm -L -p "$PID"
            printf -- '--- /proc/%s/status ---\n' "$PID"
            grep -E '^(Name|Pid|Tgid|Threads|Cpus_allowed_list):' "/proc/$PID/status"
            local t tid
            for t in /proc/"$PID"/task/*; do
                tid=$(basename "$t")
                printf -- '--- /proc/%s/task/%s/stat (поля 18,19) ---\n' "$PID" "$tid"
                awk '{printf "priority=%s nice=%s\n", $18, $19}' "$t/stat"
            done
        fi
    } > "$SERIES_TTY" 2>&1
    shot "${kind}_${tag}_c_ps"

    sleep 12
    shot "${kind}_${tag}_d_mid"

    local T_FIRST="" FIRST="" OTHER="" a1 a2
    while :; do
        a1=0
        a2=0
        alive "$A" && a1=1
        alive "$B" && a2=1
        if [ "$a1" -eq 0 ] || [ "$a2" -eq 0 ]; then
            T_FIRST=$(mono)
            if [ "$a1" -eq 0 ]; then FIRST="$A"; OTHER="$B"; else FIRST="$B"; OTHER="$A"; fi
            break
        fi
        sleep 0.05
    done
    shot "${kind}_${tag}_e_first"
    tty_line "Первым завершился участник $FIRST (t=${T_FIRST} с по /proc/uptime); второй $OTHER на этот момент $(alive "$OTHER" && echo жив || echo уже завершён)"

    if alive "$OTHER"; then
        sleep 0.6
        alive "$OTHER" && shot "${kind}_${tag}_f_second"
    fi

    local deadline=$(( $(mono | cut -d. -f1) + MAXWAIT ))
    local interrupted=""
    while alive "$A" || alive "$B"; do
        if [ "$(mono | cut -d. -f1)" -ge "$deadline" ]; then
            interrupted="таймаут ожидания второго участника (${MAXWAIT} с)"
            tty_line "ВНИМАНИЕ: $interrupted — останавливаю только PID этого прогона"
            if [ "$kind" = "05b" ]; then
                stop_run "$PID" "$prog" "Lab-05x" "$A" "$B" "$PID"
            else
                stop_run "$PID" "$prog" "$prog" "$PID"
            fi
            break
        fi
        sleep 0.2
    done

    local RC=0
    wait "$PID" || RC=$?
    sleep 0.3
    shot "${kind}_${tag}_g_finish"

    local T1
    T1=$(mono)
    {
        printf -- '--- серия %s %s: сводка ---\n' "$kind" "$tag"
        printf 'Параметры: P1=%s P2=%s P3=%s, машина %s, CPU %s, gcc %s\n' \
            "$p1" "$p2" "$p3" "$(uname -srm)" "$(nproc)" "$(gcc -dumpfullversion 2>/dev/null || echo n/a)"
        printf 'Старт: uptime %s с, конец: uptime %s с, длительность %s с\n' \
            "$T0" "$T1" "$(awk -v a="$T0" -v b="$T1" 'BEGIN{printf "%.1f", b-a}')"
        printf 'Родитель PID %s, участники %s и %s\n' "$PID" "$A" "$B"
        printf -- '--- строки завершения из лога ---\n'
        grep -E 'завершён|прерван|Все потоки' "$LOG"
        printf -- '--- интервал между завершениями участников ---\n'
        awk -v a="$(grep -E 'завершён|прерван|Все потоки' "$LOG" | grep -o 't=[0-9.]*' | cut -d= -f2 | head -1)" \
            -v b="$(grep -E 'завершён|прерван|Все потоки' "$LOG" | grep -o 't=[0-9.]*' | cut -d= -f2 | sed -n 2p)" \
            'BEGIN {
                if (a == "" || b == "") { print "  нет двух строк завершения"; exit }
                printf "  первый t=%s с, второй t=%s с, дельта %.3f с\n", a, b, b - a;
                if (b - a > 0.5)
                    print "  участники завершились в разные моменты: кадр f_second снимается, пока второй жив";
                else
                    print "  оба участника завершились в одном окне опроса: отдельный кадр f_second физически не снимается";
            }'
        printf -- '--- последние итерации участников ---\n'
        awk -F'|' -v mode="$kind" '
            /^[[:space:]]*[0-9]+ \|/ {
                it = $1; gsub(/[^0-9]/, "", it);
                if (mode == "05b") { k = $2 } else { k = $3 }
                gsub(/[^0-9]/, "", k); last[k] = it
            }
            END { for (k in last) printf "  PID/TID %s: последняя итерация %s\n", k, last[k] }
        ' "$LOG"
        printf -- '--- код возврата драйвера серии ---\n'
        if [ -n "$interrupted" ]; then
            printf 'ПРЕРВАНО: %s; код Lab-05b/c = %s (не штатное завершение)\n' "$interrupted" "$RC"
        else
            printf 'Lab-05b/c завершился штатно, код %s\n' "$RC"
        fi
        printf -- '--- кадры (имя, время снятия по /proc/uptime, SHA-256) ---\n'
        local f t0 t1 sha
        while IFS=$'\t' read -r _ f t0 t1; do
            sha=$(sha256sum "$SERIES_SHOTS/$f.png" 2>/dev/null | cut -c1-64)
            printf '  %s\t%s\t%s\n' "$f" "$t0" "${sha:0:16}"
        done < "$FRAME_LOG"
        printf -- '--- контрольные суммы бинарников ---\n'
        sha256sum ./Lab-05x ./"$prog" 2>/dev/null | sed 's/^/  /'
    } > "$SUM" 2>&1
    cat "$SUM" > "$SERIES_TTY"
}
