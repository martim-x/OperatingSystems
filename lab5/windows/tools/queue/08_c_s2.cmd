@echo off
chcp 65001 >nul
rem Lab-05c, серия 2: все CPU, процесс Normal, потоки Lowest / Highest.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\capture_05c.ps1" -P1 all -P2 Normal -P3 Lowest -P4 Highest -Tag 05c_s2 -Layout right
exit /b %errorlevel%
