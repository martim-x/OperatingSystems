@echo off
setlocal
cd /d "%~dp0"
where cl.exe >nul 2>&1
if errorlevel 1 (
    echo Run this script from a Visual Studio Developer Command Prompt. 1>&2
    exit /b 1
)
if not exist build mkdir build
for %%N in (Lab-06-bar Lab-06-conds) do (
    cl /nologo /std:c++20 /utf-8 /EHsc /O2 /W4 /WX /Fo:build\ /Fe:build\%%N.exe %%N.cpp
    if errorlevel 1 exit /b 1
)
echo BUILD OK: Lab-06-bar Lab-06-conds
