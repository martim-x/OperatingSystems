@echo off
chcp 65001 >nul
rem Сборка всех четырёх exe (MSVC ARM64). Первой командой очереди.
call "%~dp0..\..\build.cmd"
exit /b %errorlevel%
