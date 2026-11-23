#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p build

flags=(-std=c11 -O2 -Wall -Wextra -Werror -pthread)
gcc "${flags[@]}" Lab-06a.c -o build/Lab-06a
gcc "${flags[@]}" Lab-06b.c -o build/Lab-06b
printf 'BUILD OK: build/Lab-06a build/Lab-06b\n'
