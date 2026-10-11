@echo off
chcp 65001
rem ============================================
rem Cleanup.bat — очистка среды после ЛР2
rem Запускать из каталога OS2
rem ============================================

echo Удаление созданной структуры...

rem --------------------------------------------
rem Снятие атрибутов read-only и системных
rem (иначе del / rd могут не сработать)
rem --------------------------------------------
attrib -r -s -h task_01b\* /S /D
attrib -r -s -h task_01g\* /S /D
attrib -r -s -h tasks_tmp\* /S /D

rem --------------------------------------------
rem Удаление всех созданных каталогов и файлов
rem --------------------------------------------
rd /S /Q tasks_tmp
rd /S /Q task_01a
rd /S /Q task_01b
rd /S /Q task_01c_src
rd /S /Q task_01c_dst
rd /S /Q task_01d_1
rd /S /Q task_01d_2
rd /S /Q task_01e
rd /S /Q task_01f
rd /S /Q task_01g
rd /S /Q task_01h
rd /S /Q task_01i
rd /S /Q task_01j
rd /S /Q task_01k

rem --------------------------------------------
rem Удаление каталогов, созданных студентом
rem (на случай, если они остались)
rem --------------------------------------------
rd /S /Q task_01b_dst_1 2>NUL
rd /S /Q task_01b_dst_2 2>NUL

rem --------------------------------------------
rem Удаление файлов, созданных студентом
rem --------------------------------------------
del /Q user_files.txt 2>NUL
del /Q result.txt 2>NUL
del /Q merged.txt 2>NUL
del /Q console.txt 2>NUL
del /Q bat_01.bat 2>NUL
del /Q bat_02.bat 2>NUL
del /Q bat_03.bat 2>NUL
del /Q bat_04.bat 2>NUL
del /Q bat_05.bat 2>NUL

echo.
echo ============================================
echo Очистка завершена.
echo ============================================