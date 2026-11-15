@echo off
chcp 65001 >nul
rem Lab-05c, серия 1: все CPU, процесс Normal, потоки Normal / Normal.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\capture_05c.ps1" -P1 all -P2 Normal -P3 Normal -P4 Normal -Tag 05c_s1 -Layout right
exit /b %errorlevel%
