@echo off
title LaptopCheck
cd /d "%~dp0"

if not exist "%~dp0check.ps1" goto :notextracted
if not exist "%~dp0LaptopCheck.html" goto :notextracted

echo.
echo   LaptopCheck - read-only hardware check
echo   If a UAC window appears, click "Yes" (needed for SSD health).
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0check.ps1"
exit /b 0

:notextracted
echo.
echo   [!] Files are missing. Extract the whole ZIP first, then run START.bat.
echo.
pause
exit /b 1
