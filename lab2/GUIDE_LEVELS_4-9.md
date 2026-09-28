# ЛР2 — ГАЙД УРОВНИ 4–9 (НАКОПИТЕЛЬНО)

> Для уровня 9 выполнить всё из 4→5→6→7→8.
> Только клавиатура (без мыши). Справочник: ss64.com.

---

## ПОДГОТОВКА (WINDOWS + LINUX)

1. Войти под пользователем из ЛР1.
2. `cd` в домашнюю папку → создать `OS2` (`md OS2` / `mkdir OS2`).
3. Копировать `prep.bat` → запустить (`prep.bat` или `mkdir -p` вручную для Linux).

---

## УРОВЕНЬ 4–5 — ТЕОРИЯ + WINDOWS + LINUX

### ТЕОРИЯ (ОБА)
Навигация (`cd`), создание (`md`/`mkdir`), удаление (`rd`/`rmdir`/`rm -r`), копирование (`copy`/`cp`), перемещение (`move`/`mv`), переименование (`ren`/`mv`), просмотр (`dir`/`ls`), сравнение (`fc`/`diff`), удаление (`del`/`rm`), перенаправление (`>` `>>`), конвейер (`|`), сортировка (`sort`/`sort`), поиск (`find`/`grep`), вывод (`type`/`cat`).

---

### WINDOWS — КОМАНДЫ (копируй в cmd)

| № | Задание | Команда |
|---|---------|---------|
| 1 | Перейти `task_01i\Русский` (абсолютный) | `cd %USERPROFILE%\OS2\task_01i\Русский` |
| 2 | Перейти `English` (относительный) | `cd ..\English` |
| 3 | Создать `task_01j` | `md %USERPROFILE%\OS2\task_01j` |
| 4 | Иерархия `sub\dir\full\path` | `md %USERPROFILE%\OS2\task_01j\sub\dir\full\path` |
| 5 | Удалить пустой `empty_subdir` | `rd %USERPROFILE%\OS2\task_01k\empty_subdir` |
| 6 | Копировать `.txt` `tasks_tmp` → `task_01a` | `copy ...\tasks_tmp\*.txt ...\task_01a\` |
| 7 | С подтверждением перезаписи | `copy /-y ...` |
| 8 | Файл → новое имя | `copy ...\txt1.txt ...\newname.txt` |
| 9 | Объединить `txt1`+`txt2` → `merged` | `copy ...\txt1.txt + ...\txt2.txt ...\merged.txt` |
| 10 | Переместить `.txt` `src` → `dst` | `move ...\src\*.txt ...\dst\` |
| 11 | `.txt` → `.bmp` в `task_01e` | `ren ...\*.* *.bmp` |
| 12 | `txt1.bmp` → `<имя>.Ren` | `ren ...\txt1.bmp %USERNAME%.Ren` |
| 13 | Сравнить 2 файла `task_01f` → `result` (проверь `dir`!) | `fc ...\txt1.txt ...\txt2.txt > ...\result.txt` |
| 14 | Удалить `txt1` с подтверждением | `del /p ...\txt1` |
| 15 | Удалить системные | `del /as ...\*` |
| 16 | Удалить всё кроме «Только для чтения» | `del /a-r ...\*` |
| 17 | Удалить остатки + папку | `del /q ...\*` → `rd /s /q ...` |
| 18 | Постранично `C:\Windows` с подкаталогами | `dir /s /p C:\Windows` |
| 19 | `Users\%USERNAME%` → `user_files.txt` (алфавит) | `dir /on /p C:\Users\%USERNAME% > ...\user_files.txt` |
| 20 | Ввод с консоли в файл (конец Ctrl+Z) | `type con > students.txt` |
| 21 | Найти студента | `find "Иванов" students.txt` |
| 22 | Добавить в конец | `type con >> students.txt` |
| 23 | Отсортировать | `sort students.txt` |
| 24 | BIOS через промежуточный файл | `systeminfo > sysinfo.txt` → `find "BIOS" sysinfo.txt` |

**bat_01.bat** (в OS2):
```bat
@echo off
echo User: %USERNAME%
echo Date: %DATE%
echo Time: %TIME%
echo Computer: %COMPUTERNAME%
```
**bat_02.bat**:
```bat
@echo off
echo Script: %~nx0
echo Modified: %~t0
echo Path: %~f0
```
Запуск: `bat_01.bat` / `bat_02.bat`.

---

### LINUX — КОМАНДЫ (конкретно под каждое задание)

| № | Задание (как в Windows) | Bash-команда (копируй в терминал) |
|---|-------------------------|-----------------------------------|
| 1 | Перейти в папку (абсолютный) | `cd ~/OS2/task_01i/Русский` |
| 2 | Относительный переход | `cd ../English` |
| 3 | Создать папку | `mkdir -p ~/OS2/task_01j` |
| 4 | Иерархия `sub/dir/full/path` | `mkdir -p ~/OS2/task_01j/sub/dir/full/path` |
| 5 | Удалить пустую папку | `rmdir ~/OS2/task_01k/empty_subdir` |
| 6 | Копировать `.txt` из `tasks_tmp` в `task_01a` | `cp ~/OS2/tasks_tmp/*.txt ~/OS2/task_01a/` |
| 7 | С подтверждением (интерактивно) | `cp -i ~/OS2/tasks_tmp/*.txt ~/OS2/task_01a/` |
| 8 | Файл → новое имя | `cp ~/OS2/task_01a/txt1.txt ~/OS2/task_01a/newname.txt` |
| 9 | Объединить 2 файла → `merged` | `cat ~/OS2/task_01a/txt1.txt ~/OS2/task_01a/txt2.txt > ~/OS2/task_01a/merged.txt` |
| 10 | Переместить `.txt` `src` → `dst` | `mv ~/OS2/task_01c_src/*.txt ~/OS2/task_01c_dst/` |
| 11 | `.txt` → `.bmp` в `task_01e` | `cd ~/OS2/task_01e; for f in *.txt; do mv "$f" "${f%.txt}.bmp"; done` |
| 12 | Переименовать в `<имя>` | `mv ~/OS2/task_01e/txt1.bmp ~/OS2/$USER.bmp` |
| 13 | Сравнить 2 файла `task_01f` → результат | `diff ~/OS2/task_01f/txt1.txt ~/OS2/task_01f/txt2.txt > ~/OS2/task_01f/result.txt` |
| 14 | Удалить `txt1` с подтверждением | `rm -i ~/OS2/task_01g/txt1` |
| 15 | Удалить системные (через `find`) | `find ~/OS2/task_01g -type f -name '*.txt' | xargs rm -f` |
| 16 | Удалить всё кроме «только чтения» | `find ~/OS2/task_01g ! -perm -444 -type f -delete` |
| 17 | Удалить остатки + папку | `rm -rf ~/OS2/task_01g/*; rmdir ~/OS2/task_01g` |
| 18 | Постранично вывести каталог с подкаталогами | `ls -R ~/ | less` |
| 19 | Алфавитный список → файл | `ls -1 ~/OS2/task_01h > ~/OS2/task_01h/user_files.txt` |
| 20 | Ввод с консоли в файл (Ctrl+D для конца) | `cat > students.txt` |
| 21 | Найти строку в файле | `grep "Иванов" students.txt` |
| 22 | Добавить в конец | `echo "новый" >> students.txt` |
| 23 | Отсортировать файл | `sort students.txt` |
| 24 | BIOS (через файл в `/sys`) | `cat /sys/class/dmi/id/bios_version > sysinfo.txt; grep BIOS sysinfo.txt` |

**bash-скрипты (аналог bat_01 / bat_02)** — создать в OS2:
```bash
#!/bin/bash  # bat_01.sh
echo "User: $USER"
echo "Date: $(date '+%Y-%m-%d')"
echo "Time: $(date '+%H:%M:%S')"
echo "Host: $(hostname)"
```
```bash
#!/bin/bash  # bat_02.sh
echo "Script: $(basename "$0")"
echo "Modified: $(stat -c '%y' "$0")"
echo "Path: $(realpath "$0")"
```
После создания: `chmod +x bat_01.sh bat_02.sh` → запуск `./bat_01.sh`.

**Переменные Linux:** `env`. `PATH` — самая важная. `HOME` = `USERPROFILE`, `HOSTNAME` = `COMPUTERNAME`, `TMPDIR` = `TEMP`.

---

## УРОВЕНЬ 6–7 — ТЕОРИЯ + WINDOWS + LINUX

### ТЕОРИЯ
`xcopy` (`/e` — пустые папки, `/h` — скрытые/системные, `/k` — атрибуты; `/a` — архивный/только чтение), `replace`, `rd /s /q` (непустые папки), `copy con` (ввод с консоли), bat с параметрами (`%1`…`%*`), переменные окружения (`PATH`, `USERPROFILE` и др.), правила наименования (`Change Directory` = `cd` и т.д.).

---

### WINDOWS — ЗАДАНИЯ / КОМАНДЫ

| Задание | Команда |
|---|---|
| `xcopy` всё (`/e /h /k`) `task_01b` → `task_01b_dst_1` | `xcopy ...\b ...\b_dst_1 /e /h /k` |
| `xcopy` архивный+чтение (`/a /k`) → `task_01b_dst_2` | `xcopy ...\b ...\b_dst_2 /a /k` |
| `replace` из `task_01d_1` в `task_01d_2` | `replace ...\d_1\* ...\d_2\` |
| Удалить текст в файлах `task_01d_2` | `cd ...\d_2` → `type nul > *.txt` |
| Удалить непустой `subdir` в `task_01k` | `rd /s /q ...\subdir` |
| `copy con` в `console.txt` (конец Ctrl+Z) | `copy con console.txt` |
| Добавить в `console.txt` | `type con >> console.txt` |

**bat_03.bat** (параметры):
```bat
@echo off
echo All: %*
echo 1=%1 2=%2 3=%3 4=%4
```
**bat_04.bat** (арифметика, проверка деления на 0):
```bat
@echo off
if "%3"=="" (echo Usage: a b c & exit /b)
set a=%1  set b=%2  set c=%3
if %b%==0 (echo Div by 0! & exit /b)
set /a s=a+b d=a-b div=c/b m=c*b e=(a-b)*(b-a)
echo s=%s% d=%d% div=%div% m=%m% e=%e%
```
**bat_05.bat** (`create`/`delete`):
```bat
@echo off
if "%1"=="" (echo Usage: create|delete file & exit /b)
if "%1"=="create" (type nul>"%2" & echo Created) else if "%1"=="delete" (del "%2" & echo Deleted) else (echo Unknown)
```
**Переменные:** `set` в cmd. `PATH` — самая важная.

---

### LINUX — КОМАНДЫ (уровень 6-7, конкретно)

| № | Windows-задание | Bash-команда (копируй) |
|---|-----------------|------------------------|
| 1 | `xcopy /e /h /k` всё в папку | `cp -r ~/OS2/task_01b ~/OS2/task_01b_dst_1` |
| 2 | `xcopy /a /k` (атрибуты) | `cp -rp ~/OS2/task_01b ~/OS2/task_01b_dst_2` |
| 3 | `replace` файлов | `cp -f ~/OS2/task_01d_1/* ~/OS2/task_01d_2/` |
| 4 | Удалить текст в файлах папки | `cd ~/OS2/task_01d_2; for f in *.txt; do > "$f"; done` |
| 5 | Удалить непустую папку | `rm -rf ~/OS2/task_01k/subdir` |
| 6 | `copy con` → файл | `cat > ~/OS2/console.txt` (конец: Ctrl+D) |
| 7 | Добавить в конец | `echo "текст" >> ~/OS2/console.txt` |

**bash-скрипты (конкретный код):**

`bat_03.sh` — параметры:
```bash
#!/bin/bash
echo "All params: $@"
echo "1=$1 2=$2 3=$3 4=$4"
```
`bat_04.sh` — арифметика + деление на 0:
```bash
#!/bin/bash
[ $# -ne 3 ] && echo "Usage: $0 a b c" && exit 1
[ $2 -eq 0 ] && echo "Div by 0" && exit 1
echo "sum=$(( $1+$2 )) diff=$(( $1-$2 )) div=$(( $3/$2 )) mul=$(( $3*$2 )) expr=$(( ($1-$2)*($2-$1) ))"
```
`bat_05.sh` — `create` / `delete`:
```bash
#!/bin/bash
[ $# -ne 2 ] && echo "Usage: $0 create|delete file" && exit 1
case $1 in
  create) touch "$2"; echo "Created $2" ;;
  delete) rm "$2"; echo "Deleted $2" ;;
  *) echo "Unknown" ;;
esac
```

**Переменные (команда + результат):**
```bash
env  # выводит всё
# PATH — самая важная переменная
```
`PATH` = `USERPROFILE` в Windows; `HOME` = домашняя папка; `HOSTNAME` = имя компьютера; `TMPDIR` = `TEMP`.
---

## УРОВЕНЬ 8 — ТЕОРИЯ + WINDOWS + LINUX

### ТЕОРИЯ
Интерактивный калькулятор (операции `+ - * / ^ sqrt sin cos tan log ln %`, защита деления на 0, некорректный ввод) и конвертер температур (K/C/F; автоопределение по суффиксу или по умолчанию C).

---

### WINDOWS — POWERSHELL

**calc.ps1** (цикл ввода, выход `q` / Ctrl+C):
```powershell
function Invoke-Calc { param($line); ... }
while ($true) { Read-Host → Invoke-Calc → Write-Host }
```
Запуск: `powershell -ExecutionPolicy Bypass -File calc.ps1`

**tempconv.ps1** (конвертер):
```powershell
function Convert-Temp { param([string]$input); ... }
```
Запуск: `powershell -File tempconv.ps1` → ввод `100C`, `273K`, `212F`, `25`.

---

### LINUX — BASH

**path_count.sh** — полный код:
```bash
#!/bin/bash
IFS=':' read -ra dirs <<< "$PATH"
total_exec=0; total_nonexec=0
echo "Каталог в PATH -> исполняемых / неисполняемых"
for dir in "${dirs[@]}"; do
  [ -d "$dir" ] || continue
  exec_c=$(find "$dir" -maxdepth 1 -type f -executable 2>/dev/null | wc -l)
  non_c=$(find "$dir" -maxdepth 1 -type f ! -executable 2>/dev/null | wc -l)
  total_exec=$((total_exec + exec_c)); total_nonexec=$((total_nonexec + non_c))
  printf "%-30s exec:%4d nonexec:%4d\n" "$dir" "$exec_c" "$non_c"
done
echo "Всего исполняемых: $total_exec  Неисполняемых: $total_nonexec"
```
Запуск: `chmod +x path_count.sh` → `./path_count.sh`

**tree_sizes.sh** — полный код:
```bash
#!/bin/bash
target="${1:-.}"
format_size() {
  local b=$1
  [ $b -lt 1000 ] && echo "${b}B" && return
  [ $b -lt 1000000 ] && echo "$((b/1000))KB" && return
  [ $b -lt 1000000000 ] && echo "$((b/1000000))MB" && return
  echo "$((b/1000000000))GB"
}
format_iec() {
  local b=$1
  [ $b -lt 1024 ] && echo "${b}B" && return
  [ $b -lt 1048576 ] && echo "$((b/1024))KiB" && return
  [ $b -lt 1073741824 ] && echo "$((b/1048576))MiB" && return
  echo "$((b/1073741824))GiB"
}
print_tree() {
  local d="$1" ind="$2"
  for item in "$d"/*; do
    [ -e "$item" ] || continue
    [ -d "$item" ] && { echo "${ind}[D] $(basename "$item")"; print_tree "$item" "$ind  "; continue; }
    [ -f "$item" ] && { sz=$(stat -c%s "$item"); echo "${ind}[F] $(basename "$item") $(format_size $sz) / $(format_iec $sz)"; }
  done
}
print_tree "$target" ""
```
Запуск: `chmod +x tree_sizes.sh` → `./tree_sizes.sh .`

---

## УРОВЕНЬ 9 — ТЕОРИЯ + WINDOWS + LINUX

### ТЕОРИЯ
Монитор процессов в реальном времени: топ-5 по CPU и памяти, параметр `-Interval` (по умолчанию 5 сек), очистка экрана (`Clear-Host` / `clear`), таблица с временной меткой, цикл до `Ctrl+C` (`trap` для bash).

---

### WINDOWS — POWERSHELL (`top5.ps1`)
```powershell
param([int]$Interval=5)
# Get-Process | Sort CPU/WS | Select -First 5
# Формат: PID | Name | CPU(s) | Mem(MB)
# Цикл: Clear-Host → заголовок + таблица → Start-Sleep
```
Запуск: `powershell -ExecutionPolicy Bypass -File top5.ps1 -Interval 3`

---

### LINUX — BASH (`top5.sh`) — полный код
```bash
#!/bin/bash
INTERVAL=${1:-5}
trap 'echo -e "\nStopped."; exit 0' INT
format_row() { printf "%-6s %-22s %8s %10s\n" "$1" "$2" "$3" "$4"; }
while true; do
  clear
  echo "=== TOP-5 PROCESSES ==="
  echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')  |  Interval: ${INTERVAL}s  |  Ctrl+C = exit"
  echo
  echo -e "\033[1mTOP-5 BY CPU\033[0m"
  format_row "PID" "NAME" "CPU%" "MEM(MB)"
  format_row "---" "----" "----" "-------"
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -6 | tail -5 | while read pid comm cpu mem; do
    mem_kb=$(awk -v m="$mem" 'BEGIN {print int(m * 1024)}')
    format_row "$pid" "$comm" "$cpu" "${mem_kb}"
  done
  echo
  echo -e "\033[1mTOP-5 BY MEMORY\033[0m"
  format_row "PID" "NAME" "CPU%" "MEM(MB)"
  format_row "---" "----" "----" "-------"
  ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -6 | tail -5 | while read pid comm cpu mem; do
    mem_kb=$(awk -v m="$mem" 'BEGIN {print int(m * 1024)}')
    format_row "$pid" "$comm" "$cpu" "${mem_kb}"
  done
  sleep "$INTERVAL"
done
```
Запуск: `chmod +x top5.sh` → `./top5.sh 3`

---

## ЧЕК-ЛИСТ ОТЧЁТА
- [ ] Команды каждого уровня (скриншоты консоли)
- [ ] Результаты (скриншоты с пояснениями под каждым)
- [ ] Листинги `.bat` / `.ps1` / `.sh`
- [ ] Переменные окружения (`set` / `env` + анализ `PATH`)
- [ ] Таблица наименований команд с расшифровкой
- [ ] Скриншоты работы скриптов с разными параметрами
- [ ] Уровень 9 — минимум 2 кадра монитора

---

## ФАЙЛЫ РЯДОМ
- `ЛР2 ver26.pdf` — условие (docx → pdf, LibreOffice)
- `GUIDE_LEVELS_4-9.md` — этот гайд
- `GUIDE_LEVELS_4-9.pdf` — этот гайд в PDF
