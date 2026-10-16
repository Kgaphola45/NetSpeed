@echo off
if exist "%~dp0NetSpeedTaskbar.exe" (
    start "" "%~dp0NetSpeedTaskbar.exe"
) else (
    start powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File "%~dp0NetSpeedTaskbar.ps1"
)
