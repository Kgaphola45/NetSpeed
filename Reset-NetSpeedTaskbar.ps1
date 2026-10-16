<#
.SYNOPSIS
    Reset-NetSpeedTaskbar.ps1 - Reset settings, position, and session data
.DESCRIPTION
    Stops any running instances of NetSpeedTaskbar, resets the configuration
    file in %APPDATA%\NetSpeedTaskbar\config.json, and restarts the widget
    docked cleanly on the primary taskbar.
#>

[CmdletBinding()]
param(
    [switch]$NoRestart,
    [switch]$PositionOnly
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "      NetSpeedTaskbar Reset Utility       " -ForegroundColor White
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Stop running instances
Write-Host "[1/3] Terminating active NetSpeedTaskbar processes..." -ForegroundColor Yellow
$stopped = 0
try {
    $processes = Get-CimInstance Win32_Process | Where-Object { 
        ($_.Name -eq 'NetSpeedTaskbar.exe') -or 
        ($_.CommandLine -and $_.CommandLine -match 'NetSpeedTaskbar\.ps1' -and $_.ProcessId -ne $PID)
    }
    foreach ($p in $processes) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        $stopped++
    }
    if ($stopped -gt 0) {
        Write-Host "      Stopped $stopped running process(es)." -ForegroundColor Green
    } else {
        Write-Host "      No active NetSpeedTaskbar process found." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "      Warning: Could not query processes: $_" -ForegroundColor DarkYellow
}

Start-Sleep -Milliseconds 400

# 2. Reset Configuration File
$configDir  = Join-Path $env:APPDATA 'NetSpeedTaskbar'
$configFile = Join-Path $configDir 'config.json'

if ($PositionOnly) {
    Write-Host "[2/3] Resetting window position only..." -ForegroundColor Yellow
    if (Test-Path $configFile) {
        try {
            $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
            $cfg.Left   = $null
            $cfg.Top    = $null
            $cfg.Locked = $false
            $cfg | ConvertTo-Json -Depth 3 | Set-Content $configFile -Force
            Write-Host "      Position reset to auto-dock on Primary Taskbar." -ForegroundColor Green
        } catch {
            Remove-Item $configFile -Force -ErrorAction SilentlyContinue
            Write-Host "      Config reset." -ForegroundColor Green
        }
    }
} else {
    Write-Host "[2/3] Resetting all settings & data to factory defaults..." -ForegroundColor Yellow
    if (Test-Path $configFile) {
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        Write-Host "      Deleted: $configFile" -ForegroundColor Green
    } else {
        Write-Host "      Config was already empty." -ForegroundColor DarkGray
    }
}

# 3. Restart Widget
if (-not $NoRestart) {
    Write-Host "[3/3] Relaunching NetSpeedTaskbar on primary taskbar..." -ForegroundColor Yellow
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
    $exe = Join-Path $scriptDir 'NetSpeedTaskbar.exe'
    $ps1 = Join-Path $scriptDir 'NetSpeedTaskbar.ps1'

    if (Test-Path $exe) {
        Start-Process -FilePath $exe
        Write-Host "      Started NetSpeedTaskbar.exe successfully." -ForegroundColor Green
    } elseif (Test-Path $ps1) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File `"$ps1`""
        Write-Host "      Started NetSpeedTaskbar.ps1 successfully." -ForegroundColor Green
    }
} else {
    Write-Host "[3/3] Skipped relaunch (-NoRestart specified)." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "        Reset Completed Successfully!    " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
