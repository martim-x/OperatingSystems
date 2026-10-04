#!/bin/bash
# tree_sizes.sh — вывод дерева каталогов с размерами (уровень 8)
# Для каталогов — число файлов; для файлов — размер в KB/MB/GB и KiB/MiB/GiB
# Использование: ./tree_sizes.sh [каталог]   (по умолчанию текущий)

target="${1:-.}"

# Размер в десятичных единицах: KB = 1000 байт
fmt_dec() {
    awk -v b="$1" 'BEGIN {
        if (b < 1000)          printf "%d B", b
        else if (b < 1000000)   printf "%.2f KB", b/1000
        else if (b < 1000000000) printf "%.2f MB", b/1000000
        else                   printf "%.2f GB", b/1000000000
    }'
}

# Размер в двоичных единицах: KiB = 1024 байт
fmt_bin() {
    awk -v b="$1" 'BEGIN {
        if (b < 1024)            printf "%d B", b
        else if (b < 1048576)    printf "%.2f KiB", b/1024
        else if (b < 1073741824) printf "%.2f MiB", b/1048576
        else                     printf "%.2f GiB", b/1073741824
    }'
}

echo "================================================================"
echo " ДЕРЕВО КАТАЛОГОВ: $target"
echo " Формат размера файла: <десятичный> / <двоичный>"
echo "================================================================"
printf "%s[DIR ] %-40s файлов: %s, размер: %s / %s\n" "$2" "." "0" "0 B" "0 B"

print_tree() {
    local dir="$1" indent="$2"
    local fcount=0 tsize=0

    # Считаем рекурсивно по текущему каталогу
    while IFS= read -r -d '' f; do
        if [ -f "$f" ]; then
            fcount=$((fcount + 1))
            tsize=$((tsize + $(stat -c%s "$f")))
        fi
    done < <(find "$dir" -type f -print0 2>/dev/null)

    local dsize dec_size bin_size
    dsize=$(fmt_dec "$tsize")
    bin_size=$(fmt_bin "$tsize")
    printf "%s[DIR ] %-40s файлов: %d, размер: %s / %s\n" "$indent" "$(basename "$dir")" "$fcount" "$dsize" "$bin_size"

    local item name
    for item in "$dir"/* "$dir"/.[!.]*; do
        [ -e "$item" ] || continue
        name=$(basename "$item")
        if [ -d "$item" ]; then
            print_tree "$item" "$indent  "
        else
            local sz szd szb
            sz=$(stat -c%s "$item")
            szd=$(fmt_dec "$sz")
            szb=$(fmt_bin "$sz")
            printf "%s[FILE] %-40s %s / %s\n" "$indent  " "$name" "$szd" "$szb"
        fi
    done
}

print_tree "$target" ""
echo "================================================================"