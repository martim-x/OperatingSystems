#!/bin/bash
# bat_05.sh — аналог bat_05.bat: режимы create/delete
# Проверка отсутствия параметров, проверка существования файла.

if [ $# -ne 2 ]; then
    echo "Использование: $0 create|delete <файл>"
    exit 1
fi

action=$1
file=$2

case "$action" in
    create)
        if [ -e "$file" ]; then
            echo "Файл $file уже существует"
        else
            touch "$file" && echo "Создан файл $file"
        fi
        ;;
    delete)
        if [ -e "$file" ]; then
            rm "$file" && echo "Удалён файл $file"
        else
            echo "Файл $file не существует"
        fi
        ;;
    *)
        echo "Неизвестный режим: $action (допустимо: create, delete)"
        exit 1
        ;;
esac
