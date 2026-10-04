#!/bin/bash
# prep.sh — подготовка среды для ЛР2 (Linux-эквивалент Prep v2.bat)
# Запускать из каталога OS2:  bash prep.sh
#
# Скрипт идемпотентен: перед созданием структуры снимает режимы «только для
# чтения» и удаляет каталоги предыдущего прогона. Без этого повторный запуск
# падал бы на chmod 444 и копирование не создавало бы файлы.

echo "Подготовка структуры ЛР2..."

# чистка предыдущего прогона: вернуть права и убрать каталоги
chmod -R u+w . 2>/dev/null
rm -rf task_01a task_01b task_01b_dst_1 task_01b_dst_2 task_01c_src task_01c_dst \
       task_01d_1 task_01d_2 task_01e task_01f task_01g task_01h task_01i task_01j task_01k \
       tasks_tmp
rm -f students.txt console.txt bios.txt

# -----------------------------------------------
# tasks_tmp — источник файлов для копирования
# -----------------------------------------------
mkdir -p tasks_tmp
echo txt1 > tasks_tmp/txt1.txt
echo txt2 > tasks_tmp/txt2.txt
echo txt3 > tasks_tmp/txt3.txt
echo hidden1 > tasks_tmp/hidden1.txt
echo system1 > tasks_tmp/system1.txt
touch tasks_tmp/bmp1.bmp tasks_tmp/bmp2.bmp
touch tasks_tmp/exe1.exe tasks_tmp/exe2.exe
chmod 755 tasks_tmp/exe1.exe tasks_tmp/exe2.exe   # аналог исполняемых

# -----------------------------------------------
# task_01a — приёмник для cp
# -----------------------------------------------
mkdir -p task_01a

# -----------------------------------------------
# task_01b — структура для cp -r (аналог xcopy)
# -----------------------------------------------
mkdir -p task_01b/subdir/empty_subdir
echo txt1 > task_01b/subdir/txt1.txt
echo txt2 > task_01b/subdir/txt2.txt
mkdir -p task_01b/hidden_dir/empty_subdir task_01b/hidden_dir/subdir
echo txt1 > task_01b/hidden_dir/subdir/txt1.txt
echo txt2 > task_01b/hidden_dir/subdir/txt2.txt
echo txt1 > task_01b/hidden_dir/txt1.txt
echo system1 > task_01b/hidden_dir/system1.txt
echo readonly > task_01b/readonly.txt          # аналог атрибута +r
chmod 444 task_01b/readonly.txt
echo archive > task_01b/archive-readonly.txt   # аналог +a +r
chmod 444 task_01b/archive-readonly.txt
echo plain > task_01b/plain.txt                # обычный, без атрибутов
chmod 644 task_01b/plain.txt

# -----------------------------------------------
# task_01c — источник и приёмник для mv
# -----------------------------------------------
mkdir -p task_01c_src task_01c_dst
for n in 1 2 3 4 5; do echo txt1 > task_01c_src/txt$n.txt; done

# -----------------------------------------------
# task_01d — источник и приёмник для замены файлов
# -----------------------------------------------
mkdir -p task_01d_1 task_01d_2
for n in 1 2 3; do
  cp tasks_tmp/txt$n.txt task_01d_1/
  cp tasks_tmp/txt$n.txt task_01d_2/
done

# -----------------------------------------------
# task_01e — файлы для переименования
# -----------------------------------------------
mkdir -p task_01e
for n in 1 2 3 4 5; do cp tasks_tmp/txt1.txt task_01e/txt$n.txt; done

# -----------------------------------------------
# task_01f — файлы для сравнения (diff/fc)
# -----------------------------------------------
mkdir -p task_01f
printf 'Start\nHello World\nEnd\n' > task_01f/txt1.txt
printf 'Start\nHello, World!\nEnd\n' > task_01f/txt2.txt

# -----------------------------------------------
# task_01g — структура для удаления (del/rm)
# system*.txt — аналог атрибута «Системный»: в Linux такого атрибута нет,
# поэтому «системные» файлы помечены именем, их удаляет задание 15.
# readonly.txt — аналог «Только для чтения», его обязана пережить задание 16.
# -----------------------------------------------
mkdir -p task_01g/subdir/empty_subdir
echo txt1 > task_01g/subdir/txt1.txt
echo txt2 > task_01g/subdir/txt2.txt
mkdir -p task_01g/hidden_dir/empty_subdir task_01g/hidden_dir/subdir
echo txt1 > task_01g/hidden_dir/subdir/txt1.txt
echo txt2 > task_01g/hidden_dir/subdir/txt2.txt
echo txt1 > task_01g/hidden_dir/txt1.txt
echo system1 > task_01g/hidden_dir/system1.txt
echo readonly > task_01g/readonly.txt
chmod 444 task_01g/readonly.txt
echo plain > task_01g/plain.txt
echo txt1 > task_01g/txt1.txt
echo system1 > task_01g/system1.txt
echo system2 > task_01g/system2.txt

# -----------------------------------------------
# task_01h — приёмник для вывода списка
# -----------------------------------------------
mkdir -p task_01h

# -----------------------------------------------
# task_01i — каталоги для навигации
# -----------------------------------------------
mkdir -p "task_01i/Русский" task_01i/English

# -----------------------------------------------
# task_01k — каталоги для удаления
# -----------------------------------------------
mkdir -p task_01k/subdir task_01k/empty_subdir
echo file > task_01k/subdir/file.txt

echo "============================================"
echo "Подготовка завершена."
echo "============================================"