@echo off
chcp 65001 >nul
rem Lab-05b, серия 2: все CPU, классы BelowNormal / High.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\capture_05b.ps1" -P1 all -P2 BelowNormal -P3 High -Tag 05b_s2 -Layout right
exit /b %errorlevel%
