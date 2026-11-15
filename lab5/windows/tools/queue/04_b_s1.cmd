@echo off
chcp 65001 >nul
rem Lab-05b, серия 1: все CPU, классы Normal / Normal.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\capture_05b.ps1" -P1 all -P2 Normal -P3 Normal -Tag 05b_s1 -Layout right
exit /b %errorlevel%
