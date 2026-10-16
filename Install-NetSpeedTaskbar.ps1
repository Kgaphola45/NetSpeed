<#
.SYNOPSIS
    Install-NetSpeedTaskbar.ps1 - Installer for NetSpeedTaskbar
.DESCRIPTION
    Installs NetSpeedTaskbar to %LOCALAPPDATA%\Programs\NetSpeedTaskbar,
    creates Start Menu shortcuts, registers the app in Windows 11
    "Installed Apps" / "Programs and Features" (with icon, publisher, and size),
    and starts the widget.
#>

[CmdletBinding()]
param(
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     NetSpeedTaskbar Installation        " -ForegroundColor White
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$srcDir = $PSScriptRoot
if (-not $srcDir) { $srcDir = (Get-Location).Path }

$installDir = Join-Path $env:LOCALAPPDATA 'Programs\NetSpeedTaskbar'
Write-Host "[1/5] Target install directory:" -ForegroundColor Yellow
Write-Host "      $installDir" -ForegroundColor DarkGray

# 1. Stop active instances
Write-Host "[2/5] Closing active NetSpeedTaskbar processes..." -ForegroundColor Yellow
$processes = Get-CimInstance Win32_Process | Where-Object { 
    ($_.Name -eq 'NetSpeedTaskbar.exe') -or 
    ($_.CommandLine -and $_.CommandLine -match 'NetSpeedTaskbar\.ps1' -and $_.ProcessId -ne $PID)
}
foreach ($p in $processes) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 400

# 2. Create destination folder and copy files
Write-Host "[3/5] Installing application files..." -ForegroundColor Yellow
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$filesToCopy = @(
    'NetSpeedTaskbar.exe',
    'NetSpeedTaskbar.ps1',
    'NetSpeedIcon.ico',
    'Reset-NetSpeedTaskbar.bat',
    'Reset-NetSpeedTaskbar.ps1',
    'Start-NetSpeedTaskbar.bat',
    'Start-NetSpeedTaskbar.vbs',
    'README.md'
)

foreach ($f in $filesToCopy) {
    $srcFile = Join-Path $srcDir $f
    if (Test-Path $srcFile) {
        Copy-Item -Path $srcFile -Destination $installDir -Force
    }
}

# Copy or create Uninstaller in installDir
$uninstallerScript = Join-Path $installDir 'Uninstall-NetSpeedTaskbar.ps1'
$uninstallerBat    = Join-Path $installDir 'Uninstall.bat'

@"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-NetSpeedTaskbar.ps1" %*
"@ | Set-Content -Path $uninstallerBat -Force -Encoding ASCII

@"
<#
.SYNOPSIS
    Uninstall-NetSpeedTaskbar.ps1 - Uninstaller
#>
param([switch]`$Quiet)

`$installDir = `$PSScriptRoot
if (-not `$installDir) { `$installDir = Join-Path `$env:LOCALAPPDATA 'Programs\NetSpeedTaskbar' }

if (-not `$Quiet) {
    `$ans = [System.Windows.MessageBox]::Show(
        "Are you sure you want to completely uninstall NetSpeedTaskbar?",
        "Uninstall NetSpeedTaskbar",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if (`$ans -ne [System.Windows.MessageBoxResult]::Yes) { exit }
}

# 1. Stop running processes
`$procs = Get-CimInstance Win32_Process | Where-Object { 
    (`$_.Name -eq 'NetSpeedTaskbar.exe') -or 
    (`$_.CommandLine -and `$_.CommandLine -match 'NetSpeedTaskbar\.ps1' -and `$_.ProcessId -ne `$PID)
}
foreach (`$p in `$procs) { Stop-Process -Id `$p.ProcessId -Force -ErrorAction SilentlyContinue }

# 2. Remove Start Menu Shortcut
`$startMenuDir = Join-Path `$env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
`$lnkPath = Join-Path `$startMenuDir 'NetSpeedTaskbar.lnk'
if (Test-Path `$lnkPath) { Remove-Item `$lnkPath -Force -ErrorAction SilentlyContinue }

# 3. Remove Startup Run Key
`$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
Remove-ItemProperty -Path `$runKey -Name 'NetSpeedTaskbar' -ErrorAction SilentlyContinue

# 4. Remove Uninstall Registry Key
`$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NetSpeedTaskbar'
if (Test-Path `$uninstallKey) { Remove-Item `$uninstallKey -Recurse -Force -ErrorAction SilentlyContinue }

# 5. Clean AppData config if confirmed
if (-not `$Quiet) {
    `$keepData = [System.Windows.MessageBox]::Show(
        "Do you want to delete your saved traffic usage history and preferences?",
        "NetSpeedTaskbar Data",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if (`$keepData -eq [System.Windows.MessageBoxResult]::Yes) {
        `$cfgDir = Join-Path `$env:APPDATA 'NetSpeedTaskbar'
        if (Test-Path `$cfgDir) { Remove-Item `$cfgDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# 6. Self-delete install folder via detached cmd
Start-Process cmd.exe -ArgumentList "/c timeout /t 1 /nobreak >nul & rmdir /s /q `"`$installDir`"" -WindowStyle Hidden

if (-not `$Quiet) {
    [System.Windows.MessageBox]::Show("NetSpeedTaskbar was successfully uninstalled.", "Uninstall Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
}
"@ | Set-Content -Path $uninstallerScript -Force -Encoding UTF8

# 3. Create Start Menu Shortcut
Write-Host "[4/5] Creating Start Menu shortcut..." -ForegroundColor Yellow
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$lnkPath = Join-Path $startMenuDir 'NetSpeedTaskbar.lnk'
$targetExe = Join-Path $installDir 'NetSpeedTaskbar.exe'
$iconPath  = Join-Path $installDir 'NetSpeedIcon.ico'

$wshShell = New-Object -ComObject WScript.Shell
$shortcut = $wshShell.CreateShortcut($lnkPath)
$shortcut.TargetPath       = $targetExe
$shortcut.WorkingDirectory = $installDir
$shortcut.IconLocation     = "$iconPath,0"
$shortcut.Description      = "Windows 11 Transparent NetSpeed Taskbar Widget"
$shortcut.Save()

# 4. Register in Windows "Installed Apps" / "Programs and Features"
Write-Host "[5/5] Registering in Windows 'Installed Apps'..." -ForegroundColor Yellow
$uninstallRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NetSpeedTaskbar'
if (-not (Test-Path $uninstallRegPath)) {
    New-Item -ItemType Directory -Path $uninstallRegPath -Force | Out-Null
}

# Calculate total installed directory size in KB
$totalSizeKB = 0
try {
    $sizeBytes = (Get-ChildItem -Path $installDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $totalSizeKB = [int]($sizeBytes / 1024)
} catch { $totalSizeKB = 2048 }

Set-ItemProperty -Path $uninstallRegPath -Name 'DisplayName'          -Value 'NetSpeedTaskbar (Windows 11 Edition)' -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'DisplayVersion'       -Value '2.0.0' -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'Publisher'            -Value 'Emmanuel Kgaphola' -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'DisplayIcon'          -Value "$iconPath,0" -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'InstallLocation'      -Value $installDir -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'UninstallString'      -Value "`"$uninstallerBat`"" -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'QuietUninstallString' -Value "`"$uninstallerBat`" /quiet" -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'InstallDate'          -Value (Get-Date).ToString('yyyyMMdd') -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'EstimatedSize'        -Value $totalSizeKB -Type DWord -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'URLInfoAbout'         -Value 'https://github.com/Kgaphola45/NetSpeed' -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'NoModify'             -Value 1 -Type DWord -Force
Set-ItemProperty -Path $uninstallRegPath -Name 'NoRepair'             -Value 1 -Type DWord -Force

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     Installation Complete!              " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Installed to : $installDir" -ForegroundColor White
Write-Host " Start Menu   : NetSpeedTaskbar" -ForegroundColor White
Write-Host " Settings     : Listed in 'Installed apps'" -ForegroundColor White
Write-Host ""

# Launch widget
if (-not $NoLaunch) {
    Write-Host "Launching NetSpeedTaskbar..." -ForegroundColor Green
    Start-Process -FilePath $targetExe -WorkingDirectory $installDir
}
