@echo off
rem Build Lab-06a/b/c/d with the locally installed MSVC toolchain.
setlocal
chcp 65001 >nul
cd /d "%~dp0"

if defined LAB6_ARCH goto arch_ready
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "LAB6_ARCH=arm64"
if defined LAB6_ARCH goto arch_ready
set "LAB6_ARCH=x64"
:arch_ready

where cl >nul 2>&1
if not errorlevel 1 goto have_cl
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
echo BUILD FAILED: vcvarsall.bat not found.
exit /b 1

:have_vcvars
echo [i] vcvarsall: %VCVARS%
call "%VCVARS%" %LAB6_ARCH% >nul
if errorlevel 1 goto vcvars_failed
cd /d "%~dp0"
goto have_cl

:vcvars_failed
echo BUILD FAILED: could not initialize MSVC environment.
exit /b 1

:have_cl
if not exist tools mkdir tools
set "FAILED="
for %%F in (Lab-06a Lab-06b Lab-06c Lab-06d) do call :build_one %%F
if defined FAILED goto build_failed
echo.
echo === BUILD OK ===
dir /b tools\*.exe
exit /b 0

:build_one
set "NAME=%~1"
echo.
echo === %NAME%.c ===
cl /nologo /utf-8 /O2 /W4 /wd4505 /Fo:tools\ /Fd:tools\%NAME%.pdb /Fe:tools\%NAME%.exe %NAME%.c
if errorlevel 1 set "FAILED=1"
goto :eof

:build_failed
echo.
echo === BUILD FAILED ===
exit /b 1

:try_vcvars
if defined VCVARS goto :eof
if not exist "%~1\VC\Auxiliary\Build\vcvarsall.bat" goto :eof
set "VCVARS=%~1\VC\Auxiliary\Build\vcvarsall.bat"
goto :eof
