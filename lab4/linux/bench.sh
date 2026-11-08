#!/bin/sh
set -e

OUT=bench.csv
echo "program,threads,low,high,found,time" > "$OUT"

for range in "1 1048576" "1 2097152"; do
    set -- $range
    LOW=$1
    HIGH=$2
    for N in 1 2 4 8 12; do
        for prog in Lab-04p Lab-04p2 Lab-03primes; do
            out=$(./$prog $N $LOW $HIGH)
            found=$(echo "$out" | sed -n 's/^Найдено простых чисел: //p')
            t=$(echo "$out" | sed -n 's/^Время: //p' | sed 's/ с//')
            echo "$prog,$N,$LOW,$HIGH,$found,$t" >> "$OUT"
        done
    done
done

cat "$OUT"
