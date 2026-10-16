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
  - **Drag & Drop**: Left-click anywhere and drag to position it anywhere along the taskbar.
  - **Double Click**: Quick snap back to the default taskbar tray position.
  - **Right Click Context Menu (Windows 11 Dark Theme)**:
    -  **Lock Position**: Prevent accidental dragging.
    -  **Snap to Taskbar**: Realign beside system tray.
    -  **Color Scheme**: Choose between Windows 11 Fluent (Mint & Amber), Ocean (Blue & Purple), Clean Monochrome (White & Silver), or Cyber Neon (Mint & Pink).
    -  **Layout**: Switch between 2 Rows (Stacked) and 1 Row (Inline horizontal).
    -  **Refresh Interval**: 0.5s (Fast), 1.0s (Normal), or 2.0s (Battery Saver).
    -  **Start with Windows**: Toggle automatic launch on Windows startup.
    -  **Exit**: Gracefully terminate.
  - **Position Memory**: Saves your preferred position, layout, and theme to `%APPDATA%\NetSpeedTaskbar\config.json`.

## How to Run
- **Option 1 (Recommended - Completely Silent)**: Double-click `Start-NetSpeedTaskbar.vbs`. It runs silently in the background with zero command prompt flash.
- **Option 2**: Double-click `Start-NetSpeedTaskbar.bat`.
- **Option 3**: In PowerShell:
  ```powershell
  powershell -ExecutionPolicy Bypass -WindowStyle Hidden -Sta -File .\NetSpeedTaskbar.ps1
  ```
