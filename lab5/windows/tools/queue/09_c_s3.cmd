@echo off
chcp 65001 >nul
rem Lab-05c, серия 3: один CPU (маска 1), процесс Normal, потоки Lowest / Highest.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\capture_05c.ps1" -P1 1 -P2 Normal -P3 Lowest -P4 Highest -Tag 05c_s3 -Layout right
exit /b %errorlevel%
