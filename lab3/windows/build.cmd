@echo off
rem build.cmd — сборка приложений ЛР3 (Windows, ARM64, MSVC).
rem Запускается из C:\lab3 (рабочий каталог драйвера).

call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" arm64 >nul
cd /d C:\lab3

for %%F in (Lab-03x Lab-03a Lab-03b Lab-03c Lab-03d-client Lab-03d-server Lab-03hello-parent Lab-03hello-child) do (
    echo === %%F.c ===
    cl /nologo /W3 /O2 /utf-8 %%F.c
    if errorlevel 1 echo BUILD FAILED: %%F.c & exit /b 1
)

echo.
echo === BUILD OK ===
dir /b *.exe
