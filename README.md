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
    - **Data Usage & Cap Alert**:
      - Real-time tracking of **Today**, **This Month**, and **Session** traffic totals.
      - **Data Cap Limits**: Set a limit (10 GB, 25 GB, 50 GB, 100 GB, 250 GB, 500 GB, 1 TB, or custom GB).
      - **Cap Period**: Choose between **Monthly** or **Daily** cap cycles.
      - **Alert Thresholds**: Get warned when reaching **70%**, **80%**, **90%**, or **95%** of your limit.
      - **Windows Native Alerts**: Balloon/toast alert notification when reaching warning threshold or exceeding data cap.
      - **Visual Warning Dot**: An amber dot (warning) or red dot (cap exceeded) appears in the top-right corner of the taskbar widget.
      - **Independent Resets**: Reset Today, This Month, or Session counters anytime without losing configuration.
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
    - **Latency (Ping)**: Continuous non-blocking ping to Cloudflare DNS (`1.1.1.1`) with colored health dot.
    - **Session Traffic**: Total downloaded & uploaded during the current session.
    - **Today's & Monthly Usage**: Live Today and This Month cumulative data (both download and upload).
    - **Data Cap Progress & Status**: Visual progress bar showing percentage of cap consumed, with warning status.
    - **Mini Sparkline Speed Graph**: Live 30-second dual-color speed history graph with dynamic peak rate indicator.
  - **Multi-Monitor & Auto-Hide Taskbar Aware**: Accurately detects taskbar height, auto-hide taskbars, and positions seamlessly across multiple monitors.
  - **Single Instance Guard**: Uses a session mutex to ensure only one widget instance runs at a time.
  - **Persistent Storage**: Safely persists your preferences, daily/monthly data usage, and data caps to `%APPDATA%\NetSpeedTaskbar\config.json`.

## How to Run
- **Option 1 (Recommended - Completely Silent)**: Double-click `Start-NetSpeedTaskbar.vbs`. It runs silently in the background with zero command prompt flash.
- **Option 2**: Double-click `Start-NetSpeedTaskbar.bat`.
- **Option 3**: In PowerShell:
  ```powershell
  powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File .\NetSpeedTaskbar.ps1
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
