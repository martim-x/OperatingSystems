@echo off
rem ============================================================
rem  prep.bat - подготовка среды для ЛР2 (Windows)
rem  Запускать из каталога OS2:  prep.bat
rem  Идемпотентен: перед созданием структуры снимает
rem  атрибут «только для чтения» и удаляет старые каталоги.
rem ============================================================
rem Кодовую страницу не меняем: при 65001 mkdir записывает кириллическое
rem имя в UTF-8, и следующий cmd читает его как OEM - получается "?????".
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo [prep] снятие атрибутов и очистка предыдущих каталогов...
attrib -R -S -H OS2\*.* /S /D >nul 2>&1
for %%D in (task_01a task_01b task_01b_dst_1 task_01b_dst_2 task_01c_src task_01c_dst task_01d_1 task_01d_2 task_01e task_01f task_01g task_01h task_01i task_01j task_01k tasks_tmp) do (
    if exist OS2\%%D rd /S /Q OS2\%%D 2>nul
)
del /Q students.txt console.txt systeminfo.txt user_files.txt 2>nul
echo [prep] готово.
echo.

echo [prep] создание структуры OS2...
mkdir OS2 2>nul

rem --- task_01a: файлы для копирования ---
mkdir "OS2\task_01a" 2>nul

rem --- task_01b: дерево с атрибутами для xcopy ---
mkdir "OS2\task_01b\subdir" 2>nul
mkdir "OS2\task_01b\hidden_dir" 2>nul
mkdir "OS2\task_01b\subdir\empty_subdir" 2>nul
mkdir "OS2\task_01b\hidden_dir\system1" 2>nul

rem --- task_01c_src / task_01c_dst: для move ---
mkdir "OS2\task_01c_src" 2>nul
mkdir "OS2\task_01c_dst" 2>nul

rem --- task_01d_1 / task_01d_2: для replace и очистки текста ---
mkdir "OS2\task_01d_1" 2>nul
mkdir "OS2\task_01d_2" 2>nul

rem --- task_01e: файлы для переименования расширения ---
mkdir "OS2\task_01e" 2>nul

rem --- task_01f: два файла для сравнения ---
mkdir "OS2\task_01f" 2>nul

rem --- task_01g: файлы для удаления ---
mkdir "OS2\task_01g\hidden_dir" 2>nul
mkdir "OS2\task_01g\subdir" 2>nul
mkdir "OS2\task_01g\subdir\empty_subdir" 2>nul

rem --- task_01h: каталог для отчётов ---
mkdir "OS2\task_01h" 2>nul

rem --- task_01i: каталоги с кириллицей ---
mkdir "OS2\task_01i" 2>nul
mkdir "OS2\task_01i\Русский" 2>nul
mkdir "OS2\task_01i\English" 2>nul

rem --- task_01j: иерархия каталогов ---
mkdir "OS2\task_01j" 2>nul

rem --- task_01k: пустой и непустой каталоги ---
mkdir "OS2\task_01k" 2>nul
mkdir "OS2\task_01k\empty_subdir" 2>nul
mkdir "OS2\task_01k\subdir" 2>nul

rem --- tasks_tmp: исходные файлы ---
mkdir "OS2\tasks_tmp" 2>nul

rem --- содержимое файлов ---
for %%N in (1 2 3 4 5) do (
    echo txt%%N > "OS2\tasks_tmp\txt%%N.txt"
)

echo txt file 1 > "OS2\task_01g\txt1.txt"
echo txt file 2 > "OS2\task_01g\txt2.txt"
echo plain file 1 > "OS2\task_01g\plain1.txt"
echo plain file 2 > "OS2\task_01g\plain2.txt"
echo system file 1 > "OS2\task_01g\system1.txt"
echo system file 2 > "OS2\task_01g\system2.txt"
echo hidden file 1 > "OS2\task_01g\hidden1.txt"
echo read only file > "OS2\task_01g\readonly.txt"
echo sub file 1 > "OS2\task_01g\subdir\sub1.txt"
echo system file in hidden > "OS2\task_01g\hidden_dir\system1.txt"

echo Hello World > "OS2\task_01f\txt1.txt"
echo Hello, World! > "OS2\task_01f\txt2.txt"

for %%N in (1 2 3 4 5) do (
    echo file %%N content > "OS2\task_01e\txt%%N.txt"
    echo file %%N content > "OS2\task_01d_1\txt%%N.txt"
    echo file %%N to be cleared > "OS2\task_01d_2\txt%%N.txt"
)

for %%N in (1 2 3 4 5) do (
    echo archive file %%N > "OS2\task_01b\file%%N.txt"
    echo sub file %%N > "OS2\task_01b\subdir\sub%%N.txt"
)
echo archive file hidden > "OS2\task_01b\hidden_dir\hidden1.txt"
echo archive file system > "OS2\task_01b\hidden_dir\system1.txt"
echo hidden dir file > "OS2\task_01b\hidden_dir\deep1.txt"

for %%N in (1 2 3) do (
    echo c src file %%N > "OS2\task_01c_src\txt%%N.txt"
)

rem --- список студентов для заданий уровня 4 (find, sort, echo) ---
rem Тот же набор фамилий, что и в Linux-части, чтобы результаты сопоставлялись.
if not exist "OS2" mkdir "OS2" >nul 2>&1
> "OS2\students.txt" echo Иванов Иван Иванович
>> "OS2\students.txt" echo Петрова Анна Сергеевна
>> "OS2\students.txt" echo Сидоров Пётр Алексеевич
>> "OS2\students.txt" echo Кузнецов Олег Викторович
>> "OS2\students.txt" echo Смирнова Екатерина Дмитриевна
>> "OS2\students.txt" echo Волков Андрей Николаевич
>> "OS2\students.txt" echo Морозова Наталья Игоревна
>> "OS2\students.txt" echo Соколов Дмитрий Павлович
>> "OS2\students.txt" echo Новикова Мария Андреевна
>> "OS2\students.txt" echo Фёдоров Сергей Владимирович

rem --- атрибуты: archive, read-only, hidden, system ---
rem Без +A на task_01b ключ xcopy /A не скопирует ни одного файла,
rem поэтому архивный атрибут выставляется здесь, а не в bat.
for %%F in ("OS2\task_01b\*.txt") do attrib +A %%F >nul
for %%F in ("OS2\task_01b\subdir\*.txt") do attrib +A %%F >nul
attrib +R "OS2\task_01g\readonly.txt" >nul
attrib +H "OS2\task_01g\hidden1.txt" >nul
attrib +S "OS2\task_01g\system1.txt" >nul
attrib +S "OS2\task_01g\system2.txt" >nul
attrib +S "OS2\task_01g\hidden_dir\system1.txt" >nul
attrib +H "OS2\task_01b\hidden_dir\hidden1.txt" >nul
attrib +S "OS2\task_01b\hidden_dir\system1.txt" >nul

echo [prep] создание файлов и каталогов завершено.
echo.
echo [prep] итоговая структура OS2:
dir /B /S OS2 | findstr /V "^$"
echo.
echo [prep] готово. Можно выполнять задания.
exit /b 0