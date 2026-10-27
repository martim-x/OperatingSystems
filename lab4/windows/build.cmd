@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" arm64 >nul
cd /d C:\lab4
for %%F in (Lab-04a Lab-04b Lab-04c Lab-04d Lab-04p Lab-04p2 Lab-04pi) do (
    echo === %%F.c ===
    cl /nologo /W3 /O2 /utf-8 %%F.c
    if errorlevel 1 echo BUILD FAILED: %%F.c & exit /b 1
)
echo.
echo === BUILD OK ===
dir /b *.exe
