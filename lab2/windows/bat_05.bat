@echo off
rem ============================================================
rem  bat_05 - работа в режимах создание/удаление,
rem  обработка отсутствия параметров, проверка существования файла
rem ============================================================

if "%~1"=="" goto :noargs
if "%~2"=="" goto :nofile

set "MODE=%~1"
set "FILE=%~2"

if /i "%MODE%"=="create" goto :create
if /i "%MODE%"=="delete" goto :delete
echo Неизвестный режим: %MODE%
echo Допустимо: create, delete
exit /b 1

:create
if exist "%FILE%" (
    echo Файл уже существует: %FILE%
    exit /b 1
)
echo Создан файл %FILE%
> "%FILE%" echo Содержимое файла %FILE%, созданного %DATE% %TIME%
exit /b 0

:delete
if not exist "%FILE%" (
    echo Файл не найден: %FILE%
    exit /b 1
)
del /q "%FILE%"
echo Удалён файл %FILE%
exit /b 0

:noargs
echo Ошибка: не указан режим работы
echo Использование: bat_05 create^|delete имя_файла
exit /b 1

:nofile
echo Ошибка: не указано имя файла
echo Использование: bat_05 %MODE% имя_файла
exit /b 1
