#!/bin/sh
set -e

CC=gcc
CFLAGS="-O2 -pthread -Wall -Wextra"

$CC $CFLAGS -o Lab-04px Lab-04px.c
$CC $CFLAGS -o Lab-04p Lab-04p.c -lm
$CC $CFLAGS -o Lab-04p2 Lab-04p2.c -lm
$CC $CFLAGS -o Lab-04pi Lab-04pi.c -lm
$CC $CFLAGS -o Lab-03primes Lab-03primes.c -lm

echo "BUILD OK"
