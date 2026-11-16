@echo off
rem ==========================================================================
rem build.cmd - сборка ЛР5 под MSVC ARM64 (Windows 11 on ARM).
rem
rem Кодировка: UTF-8 БЕЗ BOM + chcp 65001 (cmd.exe не пропускает BOM и портит
rem первую строку файла). PowerShell-скрипты, наоборот, в UTF-8 WITH BOM.
rem
rem ВАЖНО: ни одна кириллическая строка не должна стоять внутри блока ( ... ),
rem иначе cmd.exe при коде страницы 65001 теряет байты и падает с
rem ") was unexpected at this time." Поэтому все ветвления - через goto.
rem
rem Исходники ищутся рядом с этим файлом (lab5\windows\), затем в src\.
rem Имена: Lab-05a.c или Lab_05a.c (оба варианта), Lab-05x.c, Lab-05b.c, Lab-05c.c.
rem Исходники lab5\linux - POSIX (pthreads, sched.h), MSVC их НЕ собирает:
rem для Windows нужны отдельные версии на Win32 API.
rem
rem exe кладутся в tools\ рядом с харнессом скриншотов: Lab-05b/c запускают
rem .\Lab-05x.exe из своего текущего каталога, а драйвер очереди работает
rem в tools\. obj/pdb тоже в tools\ - каталог с .c остаётся чистым.
rem ==========================================================================
setlocal
chcp 65001 >nul
cd /d "%~dp0"

rem --- 0. Архитектура цели -----------------------------------------------------
rem По умолчанию берется архитектура хоста (ARM64 -> arm64, иначе x64).
rem Переопределение: set LAB5_ARCH=x64 (или arm64) до вызова build.cmd.

if defined LAB5_ARCH goto arch_ready
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "LAB5_ARCH=arm64"
if defined LAB5_ARCH goto arch_ready
set "LAB5_ARCH=x64"
:arch_ready

rem --- 1. Окружение компилятора ---------------------------------------------

where cl >nul 2>&1
if not errorlevel 1 goto build

set "VCVARS="
call :try_vcvars "%ProgramFiles%\Microsoft Visual Studio\18\Community"
call :try_vcvars "%ProgramFiles%\Microsoft Visual Studio\18\Professional"
call :try_vcvars "%ProgramFiles%\Microsoft Visual Studio\18\Enterprise"
call :try_vcvars "%ProgramFiles%\Microsoft Visual Studio\18\BuildTools"
call :try_vcvars "%ProgramFiles%\Microsoft Visual Studio\17\Community"
call :try_vcvars "%ProgramFiles%\Microsoft Visual Studio\17\Professional"
call :try_vcvars "%ProgramFiles%\Microsoft Visual Studio\17\Enterprise"
call :try_vcvars "%ProgramFiles%\Microsoft Visual Studio\17\BuildTools"

if defined VCVARS goto have_vcvars

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto no_vcvars
for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -property installationPath`) do call :try_vcvars "%%I"
if defined VCVARS goto have_vcvars

:no_vcvars
echo BUILD FAILED: не найден vcvarsall.bat.
echo Запустите сборку из "ARM64 Native Tools Command Prompt for VS"
echo или проверьте установку "Desktop development with C++" + MSVC ARM64.
exit /b 1

:have_vcvars
echo [i] vcvarsall: %VCVARS%
call "%VCVARS%" %LAB5_ARCH% >nul
if errorlevel 1 goto vcvars_failed
rem vcvarsall/vsdevcmd могут сменить текущий каталог - возвращаемся к своему.
cd /d "%~dp0"
goto build

:vcvars_failed
echo BUILD FAILED: не удалось инициализировать окружение ARM64.
exit /b 1

rem --- 2. Сборка --------------------------------------------------------------

:build
if not exist "tools" mkdir "tools"
set "FAILED="
set "BUILT=0"

for %%F in (Lab-05a Lab-05x Lab-05b Lab-05c) do call :build_one %%F

if defined FAILED goto build_failed
if "%BUILT%"=="0" goto no_sources

echo.
echo === BUILD OK ===
dir /b tools\*.exe
exit /b 0

:build_failed
echo.
echo === BUILD FAILED ===
exit /b 1

rem --- подпрограммы -----------------------------------------------------------

:build_one
rem %1 - имя без расширения. Принимаем Lab-05a.c и POSIX-написание Lab_05a.c.
set "NAME=%~1"
set "SRC="
if exist "%NAME%.c" set "SRC=%NAME%.c"
if not defined SRC if exist "src\%NAME%.c" set "SRC=src\%NAME%.c"
if not defined SRC if exist "%NAME:_=-%.c" set "SRC=%NAME:_=-%.c"
if not defined SRC if exist "src\%NAME:_=-%.c" set "SRC=src\%NAME:_=-%.c"
if not defined SRC goto one_missing

echo.
echo === %SRC% ===
cl /nologo /utf-8 /O2 /W4 /Fo:tools\ /Fd:tools\ /Fe:tools\%NAME%.exe "%SRC%"
if errorlevel 1 goto one_failed
set /a BUILT+=1
goto :eof

:one_missing
echo [FAIL] нет исходника %NAME%.c - искал рядом и в src\
set "FAILED=1"
goto :eof

:one_failed
echo BUILD FAILED: %SRC%
set "FAILED=1"
goto :eof

:no_sources
echo BUILD FAILED: не найдено ни одного исходника Lab-05*.c
echo Искал: "%~dp0" и "%~dp0src\" - Lab-05a.c или Lab_05a.c, Lab-05x.c, Lab-05b.c, Lab-05c.c.
echo Исходники lab5\linux - POSIX (pthreads/sched.h), MSVC их не собирает:
echo для Windows нужны версии на Win32 API в lab5\windows\.
exit /b 1

:try_vcvars
if defined VCVARS goto :eof
if not exist "%~1\VC\Auxiliary\Build\vcvarsall.bat" goto :eof
set "VCVARS=%~1\VC\Auxiliary\Build\vcvarsall.bat"
goto :eof
