@echo off
chcp 65001 >nul
rem Lab-05x: 1 млн итераций, каждые 1000 - задержка 50 мс и строка вывода.
"%~dp0..\Lab-05x.exe"
exit /b %errorlevel%
