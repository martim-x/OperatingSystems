#!/bin/sh
set -e

CC=gcc
CFLAGS="-O2 -pthread -Wall -Wextra"

$CC $CFLAGS -o Lab_05a Lab_05a.c
$CC $CFLAGS -o Lab-05x Lab-05x.c
$CC $CFLAGS -o Lab-05b Lab-05b.c
$CC $CFLAGS -o Lab-05c Lab-05c.c

echo "BUILD OK"
