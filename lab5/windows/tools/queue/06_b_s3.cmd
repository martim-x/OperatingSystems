@echo off
chcp 65001 >nul
rem Lab-05b, серия 3: один CPU (маска 1), классы BelowNormal / High.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\capture_05b.ps1" -P1 1 -P2 BelowNormal -P3 High -Tag 05b_s3 -Layout right
exit /b %errorlevel%
