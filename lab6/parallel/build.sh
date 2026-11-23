#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
for name in Lab-06-bar Lab-06-conds; do
    "${CXX:-g++}" -std=c++20 -pthread -O2 -Wall -Wextra -Werror "$name.cpp" -o "build/$name"
done
printf 'BUILD OK: Lab-06-bar Lab-06-conds\n'
