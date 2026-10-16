@echo off
setlocal
title NetSpeedTaskbar - Reset Data & Settings
cd /d "%~dp0"

echo =========================================
echo       NetSpeedTaskbar Reset Utility       
echo =========================================
echo.
echo This will reset NetSpeedTaskbar:
echo  1. Terminate running widget instance
echo  2. Clear saved position and settings data
echo  3. Restart cleanly docked on your primary taskbar
echo.
set /p CONFIRM="Proceed with reset? (Y/N, default Y): "
if /i "%CONFIRM%"=="N" (
    echo.
    echo Reset cancelled.
    timeout /t 2 >nul
    exit /b 0
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reset-NetSpeedTaskbar.ps1"

echo.
echo Press any key to close this window...
pause >nul
