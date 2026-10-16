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
    - **Session Data**: View cumulative session downloaded and uploaded data with one-click counter reset.
    - **Color Scheme**: Choose between Windows 11 Fluent (Mint & Amber), Ocean (Blue & Purple), Clean Monochrome (White & Silver), or Cyber Neon (Mint & Pink).
    - **Layout**: Switch between 2 Rows (Stacked) and 1 Row (Inline horizontal).
    - **Refresh Interval**: 0.5s (Fast), 1.0s (Normal), or 2.0s (Battery Saver).
    - **Start with Windows**: Toggle automatic launch on Windows startup (runs silently with zero console window flash).
    - **Exit**: Gracefully terminate.
  - **Windows 11 Fluent Hover Card (Rich Tooltip)**:
    - **Connection Info**: Displays adapter name and active Wi-Fi SSID (e.g. `Wi-Fi (How-Wifi)`) or Ethernet controller.
    - **Network Details**: Real-time Local IPv4 Address and Default Gateway.
    - **Latency (Ping)**: Continuous non-blocking ping to Cloudflare DNS (`1.1.1.1`) with colored health dot.
    - **Session Data**: Total data downloaded & uploaded this session.
    - **Mini Sparkline Speed Graph**: Live 30-second dual-color speed history graph with dynamic peak rate indicator.
  - **Multi-Monitor & Auto-Hide Taskbar Aware**: Accurately detects taskbar height, auto-hide taskbars, and positions seamlessly across multiple monitors.
  - **Single Instance Guard**: Uses a session mutex to ensure only one widget instance runs at a time.
  - **Position Memory**: Saves your preferred position, layout, adapter, unit, shortcuts, and theme to `%APPDATA%\NetSpeedTaskbar\config.json`.

## How to Run
- **Option 1 (Recommended - Completely Silent)**: Double-click `Start-NetSpeedTaskbar.vbs`. It runs silently in the background with zero command prompt flash.
- **Option 2**: Double-click `Start-NetSpeedTaskbar.bat`.
- **Option 3**: In PowerShell:
  ```powershell
  powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File .\NetSpeedTaskbar.ps1
  ```
