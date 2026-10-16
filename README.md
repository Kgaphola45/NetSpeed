# NetSpeedTaskbar (Windows 11 Edition)

A high-performance, seamless network speed monitor built specifically for Windows 11.

## Key Features
- **Zero Background**: True per-pixel alpha transparency (`AllowsTransparency="True"`) with no rectangular box or border. The download/upload speeds float directly on the Windows 11 taskbar.
- **Windows 11 Fluent Aesthetic**:
  - Crisp typography using **Segoe UI Variable** with tabular figures (`Typography.NumeralAlignment="Tabular"`) to prevent text jittering as speeds change.
  - Windows 11 Fluent-style vector arrows for Download (Mint/Seafoam) and Upload (Warm Amber).
  - Subtle drop shadow ensuring readability across any light, dark, or translucent taskbar theme and wallpaper.
  - Fluid hover effect (translucent rounded pill highlight on mouse hover).
- **Stays on the Taskbar**:
  - Win32 `WS_EX_TOOLWINDOW`: Immune to minimization when pressing <kbd>Win</kbd> + <kbd>D</kbd> (Show Desktop).
  - Win32 `WS_EX_NOACTIVATE`: Clicking or dragging the widget never steals window focus away from your active games, browser, or editor.
  - Periodic topmost enforcement keeping it smoothly above the taskbar layer.
  - Automatically calculates Windows 11 taskbar height and docks beside the system tray / clock area.
- **Mouse Interactions & Customization**:
  - **Drag & Drop**: Left-click anywhere and drag to position it anywhere along the taskbar across any of your monitors.
  - **Configurable Click Shortcuts**:
    - **Double-Click**: Open Task Manager (Performance tab), Windows Network Settings, Network Connections, or Snap to Taskbar.
    - **Middle-Click**: Instant secondary shortcut (e.g. open Windows Network Settings or Task Manager).
  - **Right Click Context Menu (Windows 11 Dark Theme)**:
    - **Lock Position**: Prevent accidental dragging.
    - **Snap to Taskbar (Multi-Monitor)**: Realign to the tray area on your current monitor, or pick a specific screen (Monitor 1, 2, or 3).
    - **Click Shortcuts**: Configure what Double-Click and Middle-Click do.
    - **Network Adapter**: Switch between **Auto (Active Internet Gateway)**, **All Physical Adapters**, or pin to a specific adapter (e.g. Wi-Fi, Ethernet). Automatically filters out virtual clutter from WSL, Hyper-V, and VPN tunnels.
    - **Speed Unit**: Toggle between **Bytes/s** (KB/s, MB/s) for file transfer speeds and **Bits/s** (Kbps, Mbps) matching ISP bandwidth metrics.
    - **Ping / Latency Target (0 MB Internet Option)**:
      - **Local Router / Gateway (0 MB Data - Default)**: Pings your local router (e.g. `192.168.1.1` / `10.0.0.1`), consuming **zero MB of internet data** while still detecting local Wi-Fi or Ethernet network congestion and lag.
      - **Google DNS (`8.8.8.8`)**: Lightweight check against Google's global anycast DNS.
      - **Cloudflare DNS (`1.1.1.1`)**: Fast 1.1.1.1 public DNS resolver.
      - **Custom IP / Host...**: Enter any custom IP address or server.
      - **Disabled**: Turn off ping completely to maximize battery life and eliminate all background polling.
    - **Top Consumers (last 10s)**: Real-time "Top Talker" detection showing which apps are consuming bandwidth. Uses `Get-NetTCPConnection` + `Get-Process` and `\Process(*)\IO Data Bytes/sec` performance counters. Displays the top 3 processes (e.g. `Chrome.exe - 4.2 MB/s`). Click any process to jump into Windows Resource Monitor (`resmon.exe`) for in-depth per-connection diagnostics, or click **Refresh Now** to trigger an instant scan. 100% native, zero external tools.
    - **Set Data Cap (MB / GB)** & **Data Cap Alarm**:
      - **1-Click Right-Click Setup**: Direct `Set Data Cap (MB / GB)...` context menu action with an intuitive dialog accepting any unit (e.g. `500 MB`, `2000 MB`, `50 GB`, `200 GB`, `1.5 GB`, or `0` to disable).
      - **Flexible Unit Selection (MB or GB)**: Perfect for mobile hotspots and metered cellular connections with daily/monthly limits (e.g. `500 MB` or `2000 MB`) as well as broadband fiber plans (`100 GB`, `200 GB`, `500 GB`).
      - **Preset Submenus**:
        - **Gigabytes (GB) Presets**: `10 GB`, `25 GB`, `50 GB`, `100 GB`, `200 GB (Recommended)`, `500 GB`, `1 TB (1000 GB)`, or `Disabled`.
        - **Megabytes (MB) Presets**: `250 MB`, `500 MB`, `1000 MB (~1 GB)`, `2000 MB (~2 GB)`, `5000 MB (~5 GB)`.
      - **Cap Period**: Toggle between **Monthly Cap** and **Daily Cap** tracking.
      - **90% Red Alarm**: Automatically turns widget speed text and warning dot **RED** once data usage reaches 90% of your configured cap (`$usedTotal -gt $cap * 0.9`), visually alerting capped connections before overage fees occur.
      - **Tooltip Progress Bar**: Visual progress bar in the hover card with live percentage (`{0:N1}%`), color-coded states (Mint <80%, Amber 80–90%, Red >90%), and alarm status message showing exact usage vs cap in MB or GB.
      - **Windows Native Alerts**: Balloon/toast alert notification when reaching 90% alarm threshold or exceeding 100% data cap.
      - **Traffic Totals & Resets**: Real-time tracking and independent reset options for **Today**, **This Month**, and **Session**.
    - **Color Scheme**:
      - **Auto (Matches Windows Taskbar)**: Automatically detects whether your taskbar is Dark or Light and dynamically switches text colors and contrast shadows for optimal legibility.
      - **Windows 11 Fluent (Dark)**: Mint (`#38E1B0`) and Amber (`#FFA447`) with crisp white values.
      - **Windows 11 Light (High Contrast)**: Forest Emerald (`#00875A`) and Burnt Orange (`#D9531E`) with deep charcoal text (`#1A1A1A`).
      - **Ocean (Blue & Purple)**, **Clean Monochrome (White & Silver)**, or **Cyber Neon (Mint & Pink)**.
    - **Layout**: Switch between 2 Rows (Stacked) and 1 Row (Inline horizontal).
    - **Text Size (DPI Scaling)**: Choose between **Compact (Small)**, **Standard (Default)**, or **Large (1440p / 4K)** for optimal readability across any monitor resolution.
    - **Widget Opacity**: Adjust transparency to blend into custom wallpapers or tools like *TranslucentTB* (**100% Solid**, **85% Subtle Glass**, **70% Translucent**, **50% Minimal/Ghost**).
    - **Refresh Interval**: 0.5s (Fast), 1.0s (Normal), or 2.0s (Battery Saver).
    - **Start with Windows**: Toggle automatic launch on Windows startup (runs silently with zero console window flash).
    - **Reset to Factory Defaults**: 1-click restore to original factory defaults and primary taskbar docking.
    - **Exit**: Gracefully terminate.
  - **Windows 11 Fluent Hover Card (Rich Tooltip)**:
    - **Connection Info**: Displays adapter name and active Wi-Fi SSID (e.g. `Wi-Fi (How-Wifi)`) or Ethernet controller.
    - **Network Details**: Real-time Local IPv4 Address and Default Gateway.
    - **Latency (Ping)**: Continuous non-blocking ping to your selected target (Router/Gateway for 0 MB internet, Google 8.8.8.8, Cloudflare 1.1.1.1, or custom) with colored health dot.
    - **Top App Consumer**: Live readout of the highest bandwidth-consuming application (e.g. `Chrome.exe - 4.2 MB/s`).
    - **Session Traffic**: Total downloaded & uploaded during the current session.
    - **Today's & Monthly Usage**: Live Today and This Month cumulative data (both download and upload).
    - **Data Cap Progress & Status**: Visual progress bar showing percentage of cap consumed, with warning status.
    - **Mini Sparkline Speed Graph**: Live 30-second dual-color speed history graph with dynamic peak rate indicator.
  - **Multi-Monitor & Auto-Hide Taskbar Aware**: Accurately detects taskbar height, auto-hide taskbars, and positions seamlessly across multiple monitors.
  - **Single Instance Guard**: Uses a session mutex to ensure only one widget instance runs at a time.
  - **Persistent Storage**: Safely persists your preferences, daily/monthly data usage, and data caps to `%APPDATA%\NetSpeedTaskbar\config.json`.

## How to Run
- **Option 1 (Standalone Executable)**: Double-click [`NetSpeedTaskbar.exe`](file:///c:/Users/Emmanuel_Kgaphola/Downloads/NetSpeedTaskbar/NetSpeedTaskbar.exe). Zero dependencies, no console window, native high-performance standalone app with custom icon.
- **Option 2 (Completely Silent Script)**: Double-click `Start-NetSpeedTaskbar.vbs`. It runs silently in the background with zero command prompt flash.
- **Option 3**: Double-click `Start-NetSpeedTaskbar.bat`.
- **Option 4**: In PowerShell:
  ```powershell
  powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File .\NetSpeedTaskbar.ps1
  ```

### Recompiling the Executable
If you modify `NetSpeedTaskbar.ps1`, you can recompile `NetSpeedTaskbar.exe` at any time with:
```powershell
Invoke-ps2exe -inputFile .\NetSpeedTaskbar.ps1 -outputFile .\NetSpeedTaskbar.exe -noConsole -iconFile .\NetSpeedIcon.ico -sta
```

## How to Reset Data & Settings
You can reset data and settings in two easy ways:

### 1. Using the Reset Files (Quickest)
- **One-Click Reset (Batch file)**: Double-click [`Reset-NetSpeedTaskbar.bat`](file:///c:/Users/Emmanuel_Kgaphola/Downloads/NetSpeedTaskbar/Reset-NetSpeedTaskbar.bat). It stops any active instance, wipes corrupted/stale positions and settings from `%APPDATA%\NetSpeedTaskbar\config.json`, and relaunches the widget freshly docked on your primary monitor taskbar.
- **PowerShell Script**: Run [`Reset-NetSpeedTaskbar.ps1`](file:///c:/Users/Emmanuel_Kgaphola/Downloads/NetSpeedTaskbar/Reset-NetSpeedTaskbar.ps1):
  ```powershell
  # Full factory reset + restart on primary monitor:
  .\Reset-NetSpeedTaskbar.ps1

  # Reset window position only (keeps theme & preferences):
  .\Reset-NetSpeedTaskbar.ps1 -PositionOnly
  ```

### 2. From the Right-Click Context Menu
- **Reset Session Data Only**: Right-click widget -> **Session Data** -> click **Reset Session Counters**. This zeroes out the cumulative downloaded/uploaded counters and graph history without restarting or changing any of your preferences.
- **Reset All Settings & Position**: Right-click widget -> click **Reset to Factory Defaults**. This restores original settings and snaps the widget directly to the primary taskbar.
