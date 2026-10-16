<#
.SYNOPSIS
    NetSpeedTaskbar - Windows 11 Native Network Speed Taskbar Widget
.DESCRIPTION
    A solid, modern network speed monitor tailored specifically for Windows 11.
    - True transparent background (floats seamlessly on the Windows 11 taskbar)
    - Windows 11 Fluent aesthetic (Segoe UI Variable typography, vector glyphs)
    - Stays firmly on taskbar (immune to Win+D show desktop, non-activating, auto-topmost)
    - Draggable, position persistence, Windows 11 dark context menu, auto-start option
#>

# Resolve reliable script paths
$script:ScriptPath = $PSCommandPath
if (-not $script:ScriptPath) { $script:ScriptPath = $MyInvocation.MyCommand.Path }
if (-not $script:ScriptPath) { $script:ScriptPath = Join-Path (Get-Location).Path 'NetSpeedTaskbar.ps1' }
$script:ScriptDir = Split-Path -Parent $script:ScriptPath

# Ensure Single-Threaded Apartment (STA) for WPF
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Sta -File `"$($script:ScriptPath)`""
    exit
}

# Single-Instance Enforcement (Mutex per user session)
$mutexName = "Local\NetSpeedTaskbar_" + [System.Environment]::UserName
$script:appMutex = New-Object System.Threading.Mutex($false, $mutexName)
if (-not $script:appMutex.WaitOne(0, $false)) {
    # Another instance is already running
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# ------------------------------------------------------------------------------
# 1. Native Win32 Interop (Safe for 32-bit & 64-bit PowerShell)
# ------------------------------------------------------------------------------
$win32Def = @"
using System;
using System.Runtime.InteropServices;

public static class Win32 {
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    public static IntPtr GetWindowLong(IntPtr hWnd, int nIndex) {
        if (IntPtr.Size == 8) return GetWindowLongPtr64(hWnd, nIndex);
        return new IntPtr(GetWindowLong32(hWnd, nIndex));
    }

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    public static IntPtr SetWindowLong(IntPtr hWnd, int nIndex, IntPtr dwNewLong) {
        if (IntPtr.Size == 8) return SetWindowLongPtr64(hWnd, nIndex, dwNewLong);
        return new IntPtr(SetWindowLong32(hWnd, nIndex, dwNewLong.ToInt32()));
    }

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const int GWL_EXSTYLE       = -20;
    public const int WS_EX_TOOLWINDOW  = 0x00000080;
    public const int WS_EX_NOACTIVATE  = 0x08000000;
    public const int WS_EX_TOPMOST     = 0x00000008;

    public const uint SWP_NOSIZE       = 0x0001;
    public const uint SWP_NOMOVE       = 0x0002;
    public const uint SWP_NOACTIVATE   = 0x0010;
    public const uint SWP_SHOWWINDOW   = 0x0040;
}
"@
if (-not ([System.Management.Automation.PSTypeName]'Win32').Type) {
    Add-Type -TypeDefinition $win32Def -Language CSharp
}
# Note: Do not call SetProcessDPIAware() as WPF manages Per-Monitor DPI natively,
# and calling it forces legacy system DPI virtualization across secondary monitors.

# Hide host console window if launched directly
$consoleHwnd = [Win32]::GetConsoleWindow()
if ($consoleHwnd -ne [IntPtr]::Zero) {
    [Win32]::ShowWindow($consoleHwnd, 0) | Out-Null
}

# ------------------------------------------------------------------------------
# 2. Config & Persistence Management
# ------------------------------------------------------------------------------
$configDir  = Join-Path $env:APPDATA 'NetSpeedTaskbar'
$configFile = Join-Path $configDir 'config.json'
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

$defaultConfig = @{
    Left       = $null
    Top        = $null
    Locked     = $false
    Theme      = 'Fluent'       # Fluent, BluePurple, White, Cyber
    Layout     = 'Stacked'      # Stacked (2 rows), Inline (1 row)
    IntervalMs = 1000           # 500, 1000, 2000
    Adapter            = 'Auto'         # Auto, All, or Specific Adapter Name
    SpeedUnit          = 'Bytes'        # Bytes, Bits
    DoubleClickAction  = 'TaskMgr'      # TaskMgr, Snap, NetworkSettings, Connections
    MiddleClickAction  = 'NetworkSettings' # TaskMgr, Snap, NetworkSettings, Connections
    Opacity            = 1.0            # 1.0, 0.85, 0.70, 0.50
    FontSizePreset     = 'Standard'     # Small, Standard, Large
}

function Load-Config {
    if (Test-Path $configFile) {
        try {
            $json = Get-Content $configFile -Raw | ConvertFrom-Json
            $cfg = $defaultConfig.Clone()
            foreach ($prop in $json.PSObject.Properties) {
                $cfg[$prop.Name] = $prop.Value
            }
            return $cfg
        } catch { }
    }
    return $defaultConfig.Clone()
}

$script:Config = Load-Config

function Save-Config {
    try {
        $script:Config | ConvertTo-Json -Depth 3 | Set-Content $configFile -Force
    } catch { }
}

# ------------------------------------------------------------------------------
# 3. Themes Definition (Windows 11 Palettes)
# ------------------------------------------------------------------------------
$Themes = @{
    'Fluent' = @{
        DownColor = '#38E1B0'  # Windows 11 Mint / Seafoam
        UpColor   = '#FFA447'  # Windows 11 Warm Amber
        ValColor  = '#FFFFFF'  # Crisp White
        UnitColor = '#B2C4D4'  # Soft Slate
    }
    'BluePurple' = @{
        DownColor = '#60CDFF'  # Windows 11 Fluent Blue
        UpColor   = '#D177FF'  # Fluent Purple
        ValColor  = '#FFFFFF'
        UnitColor = '#B2C4D4'
    }
    'White' = @{
        DownColor = '#E0E0E0'  # Minimal White
        UpColor   = '#B0B0B0'  # Silver
        ValColor  = '#FFFFFF'
        UnitColor = '#90A0B0'
    }
    'Cyber' = @{
        DownColor = '#00FFB2'  # Electric Mint
        UpColor   = '#FF3377'  # Neon Pink
        ValColor  = '#FFFFFF'
        UnitColor = '#A4C0E0'
    }
}

# ------------------------------------------------------------------------------
# 4. WPF XAML UI (Clean, Zero-Background, Windows 11 Fluent Aesthetic)
# ------------------------------------------------------------------------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="NetSpeedTaskbar"
        Width="104" Height="42"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        Topmost="True"
        ShowInTaskbar="False"
        ResizeMode="NoResize">
    
    <Window.Resources>
        <!-- Windows 11 Dark Fluent Brushes -->
        <SolidColorBrush x:Key="MenuBgBrush" Color="#F21E1E1E"/>
        <SolidColorBrush x:Key="MenuBorderBrush" Color="#2EFFFFFF"/>
        <SolidColorBrush x:Key="MenuFgBrush" Color="#F2F2F2"/>
        <SolidColorBrush x:Key="MenuHoverBrush" Color="#1EFFFFFF"/>
        <SolidColorBrush x:Key="MenuDisabledBrush" Color="#55FFFFFF"/>

        <!-- Windows 11 Context Menu Dark Style -->
        <Style TargetType="ContextMenu">
            <Setter Property="Background" Value="{StaticResource MenuBgBrush}"/>
            <Setter Property="Foreground" Value="{StaticResource MenuFgBrush}"/>
            <Setter Property="BorderBrush" Value="{StaticResource MenuBorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="4"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ContextMenu">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8"
                                Padding="{TemplateBinding Padding}">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="14" Direction="270" ShadowDepth="4" Color="#000000" Opacity="0.7"/>
                            </Border.Effect>
                            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Windows 11 Dark MenuItem Style with Dark Submenu Popups -->
        <Style TargetType="MenuItem">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{StaticResource MenuFgBrush}"/>
            <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="MenuItem">
                        <Grid>
                            <Border Name="ItemBorder" Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}" Margin="1">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="18"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="16"/>
                                    </Grid.ColumnDefinitions>
                                    <!-- Checkmark Glyph -->
                                    <Path Name="CheckGlyph" Grid.Column="0" Data="M 2 5.5 L 5 8.5 L 10 2.5"
                                          Stroke="#38E1B0" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                          VerticalAlignment="Center" HorizontalAlignment="Left" Visibility="Collapsed"/>
                                    <!-- Header Text -->
                                    <ContentPresenter Grid.Column="1" ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center" Margin="2,0,8,0"/>
                                    <!-- Submenu Arrow -->
                                    <Path Name="SubmenuArrow" Grid.Column="2" Data="M 1 1 L 5 5 L 1 9"
                                          Stroke="#8FA3B8" StrokeThickness="1.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                                          VerticalAlignment="Center" HorizontalAlignment="Right" Visibility="Collapsed"/>
                                </Grid>
                            </Border>
                            <!-- Submenu Popup (DARK THEME) -->
                            <Popup Name="SubMenuPopup" AllowsTransparency="True" Placement="Right" VerticalOffset="-4" HorizontalOffset="2"
                                   IsOpen="{Binding Path=IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}" Focusable="False">
                                <Border Background="{StaticResource MenuBgBrush}"
                                        BorderBrush="{StaticResource MenuBorderBrush}"
                                        BorderThickness="1"
                                        CornerRadius="8"
                                        Padding="4">
                                    <Border.Effect>
                                        <DropShadowEffect BlurRadius="14" Direction="270" ShadowDepth="4" Color="#000000" Opacity="0.7"/>
                                    </Border.Effect>
                                    <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="ItemBorder" Property="Background" Value="{StaticResource MenuHoverBrush}"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="CheckGlyph" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="HasItems" Value="True">
                                <Setter TargetName="SubmenuArrow" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="{StaticResource MenuDisabledBrush}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Separator">
            <Setter Property="Background" Value="{StaticResource MenuBorderBrush}"/>
            <Setter Property="Margin" Value="6,4"/>
            <Setter Property="Height" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Separator">
                        <Rectangle Fill="{TemplateBinding Background}" Height="1" Margin="{TemplateBinding Margin}"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Windows 11 Fluent Dark ToolTip Style -->
        <Style TargetType="ToolTip">
            <Setter Property="Background" Value="#F0181818"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#33FFFFFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToolTip">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8"
                                Padding="{TemplateBinding Padding}">
                            <Border.Effect>
                                <DropShadowEffect BlurRadius="12" Direction="270" ShadowDepth="4" Color="#000000" Opacity="0.6"/>
                            </Border.Effect>
                            <ContentPresenter/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <!-- Outer Interactive Border (Transparent, subtle rounded hover pill) -->
    <Border Name="WidgetContainer"
            Background="#01000000"
            CornerRadius="6"
            Padding="6,2"
            Cursor="Hand"
            SnapsToDevicePixels="True"
            ToolTipService.InitialShowDelay="150"
            ToolTipService.ShowDuration="30000">
        
        <Border.ToolTip>
            <ToolTip Name="WidgetToolTip">
                <StackPanel Width="210">
                    <!-- Header: Active Adapter & Ping Latency -->
                    <Grid Margin="0,0,0,5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Name="TipAdapterName" Grid.Column="0" Text="Checking..." FontWeight="SemiBold" FontSize="11" Foreground="#FFFFFF" TextTrimming="CharacterEllipsis"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                            <Ellipse Name="TipPingDot" Width="6" Height="6" Fill="#808080" Margin="0,1,4,0"/>
                            <TextBlock Name="TipPingText" Text="-- ms" FontSize="10" Foreground="#A0B4C8"/>
                        </StackPanel>
                    </Grid>

                    <!-- IP and Gateway Info -->
                    <Grid Margin="0,0,0,5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="IP / Gateway:" FontSize="10" Foreground="#8FA3B8"/>
                        <TextBlock Name="TipIpGateway" Grid.Column="1" HorizontalAlignment="Right" Text="-- / --" FontSize="10" Foreground="#D0E0F0"/>
                    </Grid>

                    <Rectangle Height="1" Fill="#20FFFFFF" Margin="0,0,0,5"/>

                    <!-- Live Combined Speed -->
                    <Grid Margin="0,1">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Live Speed:" FontSize="10" Foreground="#8FA3B8"/>
                        <TextBlock Name="TipLiveSpeed" Grid.Column="1" HorizontalAlignment="Right" Text="-- KB/s" FontSize="10" Foreground="#D0E0F0"/>
                    </Grid>

                    <!-- Session Data: Download -->
                    <Grid Margin="0,1">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Session Down:" FontSize="10" Foreground="#8FA3B8"/>
                        <TextBlock Name="TipSessionDown" Grid.Column="1" HorizontalAlignment="Right" Text="0 B" FontSize="10" FontWeight="SemiBold" Foreground="#38E1B0"/>
                    </Grid>

                    <!-- Session Data: Upload -->
                    <Grid Margin="0,1">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Session Upload:" FontSize="10" Foreground="#8FA3B8"/>
                        <TextBlock Name="TipSessionUp" Grid.Column="1" HorizontalAlignment="Right" Text="0 B" FontSize="10" FontWeight="SemiBold" Foreground="#FFA447"/>
                    </Grid>

                    <Rectangle Height="1" Fill="#20FFFFFF" Margin="0,4,0,4"/>

                    <!-- Real-Time Sparkline Speed Graph (30s) -->
                    <Grid Height="34" Margin="0,1">
                        <Border Background="#12FFFFFF" CornerRadius="4" BorderBrush="#16FFFFFF" BorderThickness="1"/>
                        <Canvas Name="TipGraphCanvas" Width="210" Height="34" ClipToBounds="True">
                            <Polyline Name="TipGraphDown" Stroke="#38E1B0" StrokeThickness="1.5"/>
                            <Polyline Name="TipGraphUp" Stroke="#FFA447" StrokeThickness="1.5"/>
                        </Canvas>
                    </Grid>
                    <Grid Margin="0,1,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="History (30s)" FontSize="9" Foreground="#6C7F94"/>
                        <TextBlock Name="TipGraphPeak" Grid.Column="1" Text="Peak: 0 KB/s" FontSize="9" Foreground="#6C7F94"/>
                    </Grid>
                </StackPanel>
            </ToolTip>
        </Border.ToolTip>

        <Border.Effect>
            <!-- DropShadow ensures 100% legibility on light/dark taskbars & wallpapers -->
            <DropShadowEffect BlurRadius="4" ShadowDepth="1" Direction="315" Color="#000000" Opacity="0.8"/>
        </Border.Effect>

        <Grid Name="MainContent" VerticalAlignment="Center" HorizontalAlignment="Center">
            
            <!-- STACKED LAYOUT (2 Rows) -->
            <Grid Name="StackedLayout" Visibility="Visible">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="14"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Download Row -->
                <Path Name="IconDownStacked" Grid.Row="0" Grid.Column="0"
                      Data="M 4 1.5 L 4 7.5 M 1.5 5 L 4 7.5 L 6.5 5"
                      Stroke="#38E1B0" StrokeThickness="1.6"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"
                      VerticalAlignment="Center" HorizontalAlignment="Left" Margin="0,1,0,0"/>
                <TextBlock Grid.Row="0" Grid.Column="1"
                           FontFamily="Segoe UI Variable Text, Segoe UI"
                           Typography.NumeralAlignment="Tabular"
                           VerticalAlignment="Center" Margin="2,0,0,0">
                    <Run Name="ValDownStacked" Text="0.0" FontWeight="SemiBold" FontSize="11" Foreground="#FFFFFF"/>
                    <Run Name="UnitDownStacked" Text=" KB/s" FontWeight="Normal" FontSize="9" Foreground="#B2C4D4"/>
                </TextBlock>

                <!-- Upload Row -->
                <Path Name="IconUpStacked" Grid.Row="1" Grid.Column="0"
                      Data="M 4 7.5 L 4 1.5 M 1.5 4 L 4 1.5 L 6.5 4"
                      Stroke="#FFA447" StrokeThickness="1.6"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"
                      VerticalAlignment="Center" HorizontalAlignment="Left" Margin="0,1,0,0"/>
                <TextBlock Grid.Row="1" Grid.Column="1"
                           FontFamily="Segoe UI Variable Text, Segoe UI"
                           Typography.NumeralAlignment="Tabular"
                           VerticalAlignment="Center" Margin="2,0,0,0">
                    <Run Name="ValUpStacked" Text="0.0" FontWeight="SemiBold" FontSize="11" Foreground="#FFFFFF"/>
                    <Run Name="UnitUpStacked" Text=" KB/s" FontWeight="Normal" FontSize="9" Foreground="#B2C4D4"/>
                </TextBlock>
            </Grid>

            <!-- INLINE LAYOUT (1 Row) -->
            <StackPanel Name="InlineLayout" Orientation="Horizontal" VerticalAlignment="Center" Visibility="Collapsed">
                <Path Name="IconDownInline"
                      Data="M 4 1.5 L 4 7.5 M 1.5 5 L 4 7.5 L 6.5 5"
                      Stroke="#38E1B0" StrokeThickness="1.6"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"
                      VerticalAlignment="Center" Margin="0,1,2,0"/>
                <TextBlock FontFamily="Segoe UI Variable Text, Segoe UI" Typography.NumeralAlignment="Tabular" VerticalAlignment="Center">
                    <Run Name="ValDownInline" Text="0.0" FontWeight="SemiBold" FontSize="11" Foreground="#FFFFFF"/>
                    <Run Name="UnitDownInline" Text=" KB/s" FontWeight="Normal" FontSize="9" Foreground="#B2C4D4"/>
                </TextBlock>

                <Rectangle Width="1" Height="14" Fill="#33FFFFFF" Margin="6,0,6,0"/>

                <Path Name="IconUpInline"
                      Data="M 4 7.5 L 4 1.5 M 1.5 4 L 4 1.5 L 6.5 4"
                      Stroke="#FFA447" StrokeThickness="1.6"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"
                      VerticalAlignment="Center" Margin="0,1,2,0"/>
                <TextBlock FontFamily="Segoe UI Variable Text, Segoe UI" Typography.NumeralAlignment="Tabular" VerticalAlignment="Center">
                    <Run Name="ValUpInline" Text="0.0" FontWeight="SemiBold" FontSize="11" Foreground="#FFFFFF"/>
                    <Run Name="UnitUpInline" Text=" KB/s" FontWeight="Normal" FontSize="9" Foreground="#B2C4D4"/>
                </TextBlock>
            </StackPanel>

        </Grid>
    </Border>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$win = [System.Windows.Markup.XamlReader]::Load($reader)

# Get named elements
$container       = $win.FindName('WidgetContainer')
$stackedLayout   = $win.FindName('StackedLayout')
$inlineLayout    = $win.FindName('InlineLayout')

$iconDownStacked = $win.FindName('IconDownStacked')
$iconUpStacked   = $win.FindName('IconUpStacked')
$valDownStacked  = $win.FindName('ValDownStacked')
$unitDownStacked = $win.FindName('UnitDownStacked')
$valUpStacked    = $win.FindName('ValUpStacked')
$unitUpStacked   = $win.FindName('UnitUpStacked')

$iconDownInline  = $win.FindName('IconDownInline')
$iconUpInline    = $win.FindName('IconUpInline')
$valDownInline   = $win.FindName('ValDownInline')
$unitDownInline  = $win.FindName('UnitDownInline')
$valUpInline     = $win.FindName('ValUpInline')
$unitUpInline    = $win.FindName('UnitUpInline')

$tipAdapterName  = $win.FindName('TipAdapterName')
$tipPingDot      = $win.FindName('TipPingDot')
$tipPingText     = $win.FindName('TipPingText')
$tipIpGateway    = $win.FindName('TipIpGateway')
$tipLiveSpeed    = $win.FindName('TipLiveSpeed')
$tipSessionDown  = $win.FindName('TipSessionDown')
$tipSessionUp    = $win.FindName('TipSessionUp')
$tipGraphDown    = $win.FindName('TipGraphDown')
$tipGraphUp      = $win.FindName('TipGraphUp')
$tipGraphPeak    = $win.FindName('TipGraphPeak')

# ------------------------------------------------------------------------------
# 5. UI Setup & Themes Application
# ------------------------------------------------------------------------------
$brushConverter = New-Object System.Windows.Media.BrushConverter

function Set-ThemeColors {
    param([string]$name)
    if (-not $Themes.ContainsKey($name)) { $name = 'Fluent' }
    $t = $Themes[$name]
    $script:Config.Theme = $name

    $downBrush = $brushConverter.ConvertFromString($t.DownColor)
    $upBrush   = $brushConverter.ConvertFromString($t.UpColor)
    $valBrush  = $brushConverter.ConvertFromString($t.ValColor)
    $unitBrush = $brushConverter.ConvertFromString($t.UnitColor)

    $iconDownStacked.Stroke = $downBrush
    $iconUpStacked.Stroke   = $upBrush
    $valDownStacked.Foreground  = $valBrush
    $valUpStacked.Foreground    = $valBrush
    $unitDownStacked.Foreground = $unitBrush
    $unitUpStacked.Foreground   = $unitBrush

    $iconDownInline.Stroke = $downBrush
    $iconUpInline.Stroke   = $upBrush
    $valDownInline.Foreground  = $valBrush
    $valUpInline.Foreground    = $valBrush
    $unitDownInline.Foreground = $unitBrush
    $unitUpInline.Foreground   = $unitBrush
}

$FontPresets = @{
    'Small' = @{
        ValSize      = 9.5
        UnitSize     = 8.0
        StackedW     = 92
        StackedH     = 36
        InlineW      = 155
        InlineH      = 24
    }
    'Standard' = @{
        ValSize      = 11.0
        UnitSize     = 9.0
        StackedW     = 104
        StackedH     = 42
        InlineW      = 180
        InlineH      = 28
    }
    'Large' = @{
        ValSize      = 13.0
        UnitSize     = 10.5
        StackedW     = 124
        StackedH     = 48
        InlineW      = 215
        InlineH      = 34
    }
}

function Set-FontSizePreset([string]$preset) {
    if (-not $FontPresets.ContainsKey($preset)) { $preset = 'Standard' }
    $p = $FontPresets[$preset]
    $script:Config.FontSizePreset = $preset

    $valDownStacked.FontSize  = $p.ValSize
    $valUpStacked.FontSize    = $p.ValSize
    $valDownInline.FontSize   = $p.ValSize
    $valUpInline.FontSize     = $p.ValSize

    $unitDownStacked.FontSize = $p.UnitSize
    $unitUpStacked.FontSize   = $p.UnitSize
    $unitDownInline.FontSize  = $p.UnitSize
    $unitUpInline.FontSize    = $p.UnitSize

    if ($script:Config.Layout -eq 'Inline') {
        $win.Width  = $p.InlineW
        $win.Height = $p.InlineH
    } else {
        $win.Width  = $p.StackedW
        $win.Height = $p.StackedH
    }
}

function Set-LayoutMode {
    param([string]$mode)
    $preset = if ($FontPresets.ContainsKey($script:Config.FontSizePreset)) { $script:Config.FontSizePreset } else { 'Standard' }
    $p = $FontPresets[$preset]

    if ($mode -eq 'Inline') {
        $stackedLayout.Visibility = [System.Windows.Visibility]::Collapsed
        $inlineLayout.Visibility  = [System.Windows.Visibility]::Visible
        $win.Width  = $p.InlineW
        $win.Height = $p.InlineH
        $script:Config.Layout = 'Inline'
    } else {
        $stackedLayout.Visibility = [System.Windows.Visibility]::Visible
        $inlineLayout.Visibility  = [System.Windows.Visibility]::Collapsed
        $win.Width  = $p.StackedW
        $win.Height = $p.StackedH
        $script:Config.Layout = 'Stacked'
    }
}

function Set-WidgetOpacity([double]$val) {
    if ($val -lt 0.3 -or $val -gt 1.0) { $val = 1.0 }
    $script:Config.Opacity = $val
    $win.Opacity = $val
}

Set-ThemeColors $script:Config.Theme

$initFont = if ($script:Config.FontSizePreset) { $script:Config.FontSizePreset } else { 'Standard' }
Set-FontSizePreset $initFont

$initLayout = if ($script:Config.Layout) { $script:Config.Layout } else { 'Stacked' }
Set-LayoutMode $initLayout

$initOpacity = if ($null -ne $script:Config.Opacity) { [double]$script:Config.Opacity } else { 1.0 }
Set-WidgetOpacity $initOpacity

# Hover effect: subtle rounded Windows 11 pill highlight on mouse hover
$hoverBrush       = $brushConverter.ConvertFromString('#16FFFFFF')
$transparentBrush = $brushConverter.ConvertFromString('#01000000')

$container.Add_MouseEnter({
    $container.Background = $hoverBrush
})
$container.Add_MouseLeave({
    $container.Background = $transparentBrush
})

# ------------------------------------------------------------------------------
# 6. Windows 11 Taskbar Snapping & Multi-Monitor / Auto-Hide Support
# ------------------------------------------------------------------------------
function Get-CurrentScreen {
    try {
        $pt = New-Object System.Drawing.Point([int]($win.Left + ($win.Width / 2)), [int]($win.Top + ($win.Height / 2)))
        return [System.Windows.Forms.Screen]::FromPoint($pt)
    } catch {
        return [System.Windows.Forms.Screen]::PrimaryScreen
    }
}

function Snap-ToPrimaryTaskbar {
    $primW  = [System.Windows.SystemParameters]::PrimaryScreenWidth
    $primH  = [System.Windows.SystemParameters]::PrimaryScreenHeight
    $work   = [System.Windows.SystemParameters]::WorkArea
    $tbH    = $primH - $work.Height
    $isAutoHide = ($tbH -lt 10)
    if ($isAutoHide) { $tbH = 48 }

    $winWidth  = if ($win.ActualWidth -gt 0) { $win.ActualWidth } else { $win.Width }
    $winHeight = if ($win.ActualHeight -gt 0) { $win.ActualHeight } else { $win.Height }

    $win.Left = [Math]::Max(10, ($primW - $winWidth - 240))
    if ($isAutoHide) {
        $win.Top = $primH - $winHeight - 4
    } else {
        $win.Top = $work.Bottom + [Math]::Max(0, ($tbH - $winHeight) / 2)
    }

    $script:Config.Left = $win.Left
    $script:Config.Top  = $win.Top
    Save-Config
}

function Snap-ToTaskbar {
    param([System.Windows.Forms.Screen]$targetScreen = $null)
    if (-not $targetScreen -or $targetScreen.Primary) {
        Snap-ToPrimaryTaskbar
        return
    }

    $bounds = $targetScreen.Bounds
    $work   = $targetScreen.WorkingArea
    $tbHeight = $bounds.Bottom - $work.Bottom
    $isAutoHide = ($tbHeight -lt 10)
    if ($isAutoHide) {
        $tbHeight = 48
    }

    $winWidth  = if ($win.ActualWidth -gt 0) { $win.ActualWidth } else { $win.Width }
    $winHeight = if ($win.ActualHeight -gt 0) { $win.ActualHeight } else { $win.Height }

    # Scale factor between WinForms physical coordinates and WPF DIPs
    $scale = 1.0
    if ([System.Windows.SystemParameters]::PrimaryScreenWidth -gt 0 -and [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width -gt 0) {
        $scale = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width / [System.Windows.SystemParameters]::PrimaryScreenWidth
    }
    if ($scale -le 0) { $scale = 1.0 }

    $bLeft   = $bounds.Left / $scale
    $bRight  = $bounds.Right / $scale
    $bBottom = $bounds.Bottom / $scale
    $wBottom = $work.Bottom / $scale

    $win.Left = [Math]::Max($bLeft + 10, ($bRight - $winWidth - 240))
    if ($isAutoHide) {
        $win.Top = $bBottom - $winHeight - 4
    } else {
        $win.Top = $wBottom + [Math]::Max(0, (($tbHeight / $scale) - $winHeight) / 2)
    }

    $script:Config.Left = $win.Left
    $script:Config.Top  = $win.Top
    Save-Config
}

# Restore saved position or snap to taskbar
if ($null -ne $script:Config.Left -and $null -ne $script:Config.Top) {
    $virtL = [System.Windows.SystemParameters]::VirtualScreenLeft
    $virtT = [System.Windows.SystemParameters]::VirtualScreenTop
    $virtR = $virtL + [System.Windows.SystemParameters]::VirtualScreenWidth
    $virtB = $virtT + [System.Windows.SystemParameters]::VirtualScreenHeight

    $savedL = [double]$script:Config.Left
    $savedT = [double]$script:Config.Top

    # Window must be within virtual desktop bounds
    if ($savedL -ge ($virtL - 10) -and $savedL -le ($virtR - 40) -and
        $savedT -ge ($virtT - 10) -and $savedT -le ($virtB - 20)) {
        $win.Left = $savedL
        $win.Top  = $savedT
    } else {
        Snap-ToPrimaryTaskbar
    }
} else {
    Snap-ToPrimaryTaskbar
}

# ------------------------------------------------------------------------------
# 7. Drag & Drop Repositioning & Configurable Click Actions
# ------------------------------------------------------------------------------
function Invoke-ClickAction([string]$action) {
    switch ($action) {
        'TaskMgr' {
            try { Start-Process taskmgr.exe } catch { }
        }
        'NetworkSettings' {
            try { Start-Process 'ms-settings:network' } catch { }
        }
        'Connections' {
            try { Start-Process ncpa.cpl } catch { }
        }
        'Snap' {
            Snap-ToPrimaryTaskbar
        }
    }
}

$container.Add_MouseLeftButtonDown({
    param($s, $e)
    if ($e.ClickCount -ge 2) {
        Invoke-ClickAction $script:Config.DoubleClickAction
        return
    }
    if (-not $script:Config.Locked) {
        try {
            $win.DragMove()
            $script:Config.Left = $win.Left
            $script:Config.Top  = $win.Top
            Save-Config
        } catch { }
    }
})

$container.Add_MouseDown({
    param($s, $e)
    if ($e.ChangedButton -eq [System.Windows.Input.MouseButton]::Middle) {
        Invoke-ClickAction $script:Config.MiddleClickAction
    }
})

# ------------------------------------------------------------------------------
# 8. Windows 11 Dark Context Menu
$menu = New-Object System.Windows.Controls.ContextMenu
$menu.Resources = $win.Resources
$menu.Style     = $win.FindResource([System.Windows.Controls.ContextMenu])

# Auto-dismiss ContextMenu when clicking any leaf MenuItem
$menu.AddHandler([System.Windows.Controls.MenuItem]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    if ($e.OriginalSource -is [System.Windows.Controls.MenuItem]) {
        $mi = [System.Windows.Controls.MenuItem]$e.OriginalSource
        if (-not $mi.HasItems) {
            $menu.IsOpen = $false
        }
    }
})

# Lock Position
$menuLock = New-Object System.Windows.Controls.MenuItem
$menuLock.Header = 'Lock Position'
$menuLock.IsCheckable = $true
$menuLock.IsChecked   = [bool]$script:Config.Locked
$menuLock.Add_Click({
    $script:Config.Locked = $menuLock.IsChecked
    Save-Config
})
$menu.Items.Add($menuLock) | Out-Null

# Snap to Taskbar Submenu (Multi-Monitor aware)
$menuSnap = New-Object System.Windows.Controls.MenuItem
$menuSnap.Header = 'Snap to Taskbar'

$snapPrimaryItem = New-Object System.Windows.Controls.MenuItem
$snapPrimaryItem.Header = 'Snap to Primary Monitor'
$snapPrimaryItem.Add_Click({ Snap-ToPrimaryTaskbar })
$menuSnap.Items.Add($snapPrimaryItem) | Out-Null

$snapCurrentItem = New-Object System.Windows.Controls.MenuItem
$snapCurrentItem.Header = 'Snap to Current Screen'
$snapCurrentItem.Add_Click({ Snap-ToTaskbar (Get-CurrentScreen) })
$menuSnap.Items.Add($snapCurrentItem) | Out-Null

try {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    if ($screens.Count -gt 1) {
        $menuSnap.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
        for ($si = 0; $si -lt $screens.Count; $si++) {
            $scr = $screens[$si]
            $itemScr = New-Object System.Windows.Controls.MenuItem
            $primLabel = if ($scr.Primary) { ' (Primary)' } else { '' }
            $itemScr.Header = "Monitor $($si + 1)$primLabel - $($scr.Bounds.Width)x$($scr.Bounds.Height)"
            $itemScr.Tag = $scr
            $itemScr.Add_Click({
                param($s, $e)
                Snap-ToTaskbar $s.Tag
            })
            $menuSnap.Items.Add($itemScr) | Out-Null
        }
    }
} catch { }

$menu.Items.Add($menuSnap) | Out-Null

# Click Shortcuts Submenu
$menuActions = New-Object System.Windows.Controls.MenuItem
$menuActions.Header = 'Click Shortcuts'

$actionOptions = @(
    @{ Id = 'TaskMgr';         Name = 'Task Manager (Performance)' },
    @{ Id = 'NetworkSettings'; Name = 'Windows Network Settings' },
    @{ Id = 'Connections';     Name = 'Network Connections (ncpa.cpl)' },
    @{ Id = 'Snap';            Name = 'Snap to Taskbar' }
)

# Double-Click Submenu
$menuDoubleClick = New-Object System.Windows.Controls.MenuItem
$menuDoubleClick.Header = 'Double-Click Action'
foreach ($opt in $actionOptions) {
    $itemOpt = New-Object System.Windows.Controls.MenuItem
    $itemOpt.Header = $opt.Name
    $itemOpt.Tag    = $opt.Id
    $itemOpt.IsChecked = ($script:Config.DoubleClickAction -eq $opt.Id)
    $itemOpt.Add_Click({
        param($s, $e)
        $script:Config.DoubleClickAction = $s.Tag
        Save-Config
        foreach ($sub in $menuDoubleClick.Items) { $sub.IsChecked = ($sub.Tag -eq $s.Tag) }
    })
    $menuDoubleClick.Items.Add($itemOpt) | Out-Null
}
$menuActions.Items.Add($menuDoubleClick) | Out-Null

# Middle-Click Submenu
$menuMiddleClick = New-Object System.Windows.Controls.MenuItem
$menuMiddleClick.Header = 'Middle-Click Action'
foreach ($opt in $actionOptions) {
    $itemOpt = New-Object System.Windows.Controls.MenuItem
    $itemOpt.Header = $opt.Name
    $itemOpt.Tag    = $opt.Id
    $itemOpt.IsChecked = ($script:Config.MiddleClickAction -eq $opt.Id)
    $itemOpt.Add_Click({
        param($s, $e)
        $script:Config.MiddleClickAction = $s.Tag
        Save-Config
        foreach ($sub in $menuMiddleClick.Items) { $sub.IsChecked = ($sub.Tag -eq $s.Tag) }
    })
    $menuMiddleClick.Items.Add($itemOpt) | Out-Null
}
$menuActions.Items.Add($menuMiddleClick) | Out-Null

$menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# Network Adapter Submenu
$menuAdapter = New-Object System.Windows.Controls.MenuItem
$menuAdapter.Header = 'Network Adapter'

function Update-AdapterMenu {
    $menuAdapter.Items.Clear()

    # Option: Auto
    $itemAuto = New-Object System.Windows.Controls.MenuItem
    $itemAuto.Header = 'Auto (Active Gateway)'
    $itemAuto.Tag    = 'Auto'
    $itemAuto.IsChecked = ($script:Config.Adapter -eq 'Auto')
    $itemAuto.Add_Click({
        param($s, $e)
        $script:Config.Adapter = 'Auto'
        $script:prevTotals = Get-NetworkTotals
        Save-Config
        Update-AdapterMenu
    })
    $menuAdapter.Items.Add($itemAuto) | Out-Null

    # Option: All
    $itemAll = New-Object System.Windows.Controls.MenuItem
    $itemAll.Header = 'All Physical Adapters'
    $itemAll.Tag    = 'All'
    $itemAll.IsChecked = ($script:Config.Adapter -eq 'All')
    $itemAll.Add_Click({
        param($s, $e)
        $script:Config.Adapter = 'All'
        $script:prevTotals = Get-NetworkTotals
        Save-Config
        Update-AdapterMenu
    })
    $menuAdapter.Items.Add($itemAll) | Out-Null

    $menuAdapter.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

    # Dynamically enumerate non-loopback adapters
    try {
        $ifaces = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object { $_.NetworkInterfaceType -notin 'Loopback', 'Tunnel' } |
            Sort-Object -Property OperationalStatus, Name -Descending

        foreach ($iface in $ifaces) {
            $statusStr = if ($iface.OperationalStatus -eq 'Up') { '' } else { ' (Offline)' }
            $item = New-Object System.Windows.Controls.MenuItem
            $item.Header = "$($iface.Name)$statusStr"
            $item.Tag    = $iface.Name
            $item.IsChecked = ($script:Config.Adapter -eq $iface.Name)
            $item.Add_Click({
                param($s, $e)
                $script:Config.Adapter = $s.Tag
                $script:prevTotals = Get-NetworkTotals
                Save-Config
                Update-AdapterMenu
            })
            $menuAdapter.Items.Add($item) | Out-Null
        }
    } catch { }
}
Update-AdapterMenu
$menu.Items.Add($menuAdapter) | Out-Null

# Speed Unit Submenu (Bits vs Bytes)
$menuUnit = New-Object System.Windows.Controls.MenuItem
$menuUnit.Header = 'Speed Unit'

$unitBytesItem = New-Object System.Windows.Controls.MenuItem
$unitBytesItem.Header = 'Bytes/s (KB/s, MB/s)'
$unitBytesItem.IsChecked = ($script:Config.SpeedUnit -ne 'Bits')

$unitBitsItem = New-Object System.Windows.Controls.MenuItem
$unitBitsItem.Header = 'Bits/s (Kbps, Mbps)'
$unitBitsItem.IsChecked = ($script:Config.SpeedUnit -eq 'Bits')

$unitBytesItem.Add_Click({
    $script:Config.SpeedUnit = 'Bytes'
    $unitBytesItem.IsChecked = $true
    $unitBitsItem.IsChecked  = $false
    Save-Config
})
$unitBitsItem.Add_Click({
    $script:Config.SpeedUnit = 'Bits'
    $unitBytesItem.IsChecked = $false
    $unitBitsItem.IsChecked  = $true
    Save-Config
})
$menuUnit.Items.Add($unitBytesItem) | Out-Null
$menuUnit.Items.Add($unitBitsItem) | Out-Null
$menu.Items.Add($menuUnit) | Out-Null

# Session Data Submenu
$menuSession = New-Object System.Windows.Controls.MenuItem
$menuSession.Header = 'Session Data'

$itemSessionDown = New-Object System.Windows.Controls.MenuItem
$itemSessionDown.Header = 'Downloaded: 0 B'
$itemSessionDown.IsEnabled = $false

$itemSessionUp = New-Object System.Windows.Controls.MenuItem
$itemSessionUp.Header = 'Uploaded: 0 B'
$itemSessionUp.IsEnabled = $false

$itemSessionReset = New-Object System.Windows.Controls.MenuItem
$itemSessionReset.Header = 'Reset Session Counters'
$itemSessionReset.Add_Click({
    $script:sessionRxBytes = 0L
    $script:sessionTxBytes = 0L
})

# Dynamic update on context menu opening
$menuSession.Add_SubmenuOpened({
    $itemSessionDown.Header = "Downloaded: $(Format-DataSize $script:sessionRxBytes)"
    $itemSessionUp.Header   = "Uploaded:   $(Format-DataSize $script:sessionTxBytes)"
})

$menuSession.Items.Add($itemSessionDown) | Out-Null
$menuSession.Items.Add($itemSessionUp) | Out-Null
$menuSession.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
$menuSession.Items.Add($itemSessionReset) | Out-Null
$menu.Items.Add($menuSession) | Out-Null

# Color Scheme Submenu
$menuThemes = New-Object System.Windows.Controls.MenuItem
$menuThemes.Header = 'Color Scheme'

$themeItems = @(
    @{ Id = 'Fluent';     Name = 'Windows 11 Fluent (Mint & Amber)' },
    @{ Id = 'BluePurple'; Name = 'Ocean (Fluent Blue & Purple)' },
    @{ Id = 'White';      Name = 'Clean Monochrome (White & Silver)' },
    @{ Id = 'Cyber';      Name = 'Cyber Neon (Mint & Pink)' }
)
foreach ($ti in $themeItems) {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $ti.Name
    $item.Tag    = $ti.Id
    $item.IsChecked = ($script:Config.Theme -eq $ti.Id)
    $item.Add_Click({
        param($s, $e)
        Set-ThemeColors $s.Tag
        Save-Config
        foreach ($sub in $menuThemes.Items) { $sub.IsChecked = ($sub.Tag -eq $s.Tag) }
    })
    $menuThemes.Items.Add($item) | Out-Null
}
$menu.Items.Add($menuThemes) | Out-Null

# Layout Submenu
$menuLayout = New-Object System.Windows.Controls.MenuItem
$menuLayout.Header = 'Layout'

$layoutStackedItem = New-Object System.Windows.Controls.MenuItem
$layoutStackedItem.Header = '2 Rows (Stacked)'
$layoutStackedItem.IsChecked = ($script:Config.Layout -ne 'Inline')

$layoutInlineItem = New-Object System.Windows.Controls.MenuItem
$layoutInlineItem.Header = '1 Row (Inline)'
$layoutInlineItem.IsChecked = ($script:Config.Layout -eq 'Inline')

$layoutStackedItem.Add_Click({
    Set-LayoutMode 'Stacked'
    $layoutStackedItem.IsChecked = $true
    $layoutInlineItem.IsChecked  = $false
    Save-Config
})
$layoutInlineItem.Add_Click({
    Set-LayoutMode 'Inline'
    $layoutStackedItem.IsChecked = $false
    $layoutInlineItem.IsChecked  = $true
    Save-Config
})
$menuLayout.Items.Add($layoutStackedItem) | Out-Null
$menuLayout.Items.Add($layoutInlineItem) | Out-Null
$menu.Items.Add($menuLayout) | Out-Null

# Text Size / Scaling Submenu
$menuSize = New-Object System.Windows.Controls.MenuItem
$menuSize.Header = 'Text Size (DPI Scaling)'

$sizeOptions = @(
    @{ Id = 'Small';    Name = 'Compact (Small)' },
    @{ Id = 'Standard'; Name = 'Standard (Default)' },
    @{ Id = 'Large';    Name = 'Large (1440p / 4K)' }
)
foreach ($so in $sizeOptions) {
    $itemSo = New-Object System.Windows.Controls.MenuItem
    $itemSo.Header = $so.Name
    $itemSo.Tag    = $so.Id
    $itemSo.IsChecked = ($script:Config.FontSizePreset -eq $so.Id)
    $itemSo.Add_Click({
        param($s, $e)
        Set-FontSizePreset $s.Tag
        Save-Config
        foreach ($sub in $menuSize.Items) { $sub.IsChecked = ($sub.Tag -eq $s.Tag) }
    })
    $menuSize.Items.Add($itemSo) | Out-Null
}
$menu.Items.Add($menuSize) | Out-Null

# Widget Opacity Submenu
$menuOpacity = New-Object System.Windows.Controls.MenuItem
$menuOpacity.Header = 'Widget Opacity'

$opacityOptions = @(
    @{ Val = 1.0;  Name = '100% (Solid)' },
    @{ Val = 0.85; Name = '85% (Subtle Glass)' },
    @{ Val = 0.70; Name = '70% (Translucent)' },
    @{ Val = 0.50; Name = '50% (Ghost / Minimal)' }
)
foreach ($op in $opacityOptions) {
    $itemOp = New-Object System.Windows.Controls.MenuItem
    $itemOp.Header = $op.Name
    $itemOp.Tag    = $op.Val
    $itemOp.IsChecked = ([Math]::Abs($script:Config.Opacity - $op.Val) -lt 0.05)
    $itemOp.Add_Click({
        param($s, $e)
        Set-WidgetOpacity ([double]$s.Tag)
        Save-Config
        foreach ($sub in $menuOpacity.Items) { $sub.IsChecked = ($sub.Tag -eq $s.Tag) }
    })
    $menuOpacity.Items.Add($itemOp) | Out-Null
}
$menu.Items.Add($menuOpacity) | Out-Null

# Refresh Rate Submenu
$menuRate = New-Object System.Windows.Controls.MenuItem
$menuRate.Header = 'Refresh Interval'
$rates = @(
    @{ Ms = 500;  Name = 'Fast (0.5s)' },
    @{ Ms = 1000; Name = 'Normal (1.0s)' },
    @{ Ms = 2000; Name = 'Battery Saver (2.0s)' }
)
foreach ($r in $rates) {
    $rItem = New-Object System.Windows.Controls.MenuItem
    $rItem.Header = $r.Name
    $rItem.Tag    = $r.Ms
    $rItem.IsChecked = ($script:Config.IntervalMs -eq $r.Ms)
    $rItem.Add_Click({
        param($s, $e)
        $script:Config.IntervalMs = [int]$s.Tag
        $timer.Interval = [TimeSpan]::FromMilliseconds($script:Config.IntervalMs)
        Save-Config
        foreach ($sub in $menuRate.Items) { $sub.IsChecked = ($sub.Tag -eq $s.Tag) }
    })
    $menuRate.Items.Add($rItem) | Out-Null
}
$menu.Items.Add($menuRate) | Out-Null

$menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# Start with Windows (Registry Run Key)
$runKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runKeyName = 'NetSpeedTaskbar'

function Test-StartupEnabled {
    $val = (Get-ItemProperty -Path $runKeyPath -Name $runKeyName -ErrorAction SilentlyContinue).$runKeyName
    return [bool]$val
}

$menuStartup = New-Object System.Windows.Controls.MenuItem
$menuStartup.Header = 'Start with Windows'
$menuStartup.IsCheckable = $true
$menuStartup.IsChecked = Test-StartupEnabled
$menuStartup.Add_Click({
    if ($menuStartup.IsChecked) {
        $vbs = Join-Path $script:ScriptDir 'Start-NetSpeedTaskbar.vbs'
        if (Test-Path $vbs) {
            $cmd = "wscript.exe `"$vbs`""
        } else {
            $cmd = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Sta -File `"$($script:ScriptPath)`""
        }
        Set-ItemProperty -Path $runKeyPath -Name $runKeyName -Value $cmd -Force
    } else {
        Remove-ItemProperty -Path $runKeyPath -Name $runKeyName -ErrorAction SilentlyContinue
    }
})
$menu.Items.Add($menuStartup) | Out-Null

$menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# Exit
$menuExit = New-Object System.Windows.Controls.MenuItem
$menuExit.Header = 'Exit'
$menuExit.Add_Click({
    $timer.Stop()
    $win.Close()
})
$menu.Items.Add($menuExit) | Out-Null

# Clean up mutex and ping resources when window closes
$win.Add_Closed({
    try {
        if ($script:appMutex) {
            $script:appMutex.ReleaseMutex()
            $script:appMutex.Dispose()
        }
        if ($script:pingObj) {
            $script:pingObj.Dispose()
        }
    } catch { }
})

$container.ContextMenu = $menu

# ------------------------------------------------------------------------------
# 9. Taskbar Attachment & Anti-Minimization (Win32 Hooking)
# ------------------------------------------------------------------------------
$script:hwnd = [IntPtr]::Zero

$win.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($win)
    $script:hwnd = $helper.Handle

    # Apply WS_EX_TOOLWINDOW (immune to Win+D show desktop) + WS_EX_NOACTIVATE (no focus steal)
    $exStyle = [Win32]::GetWindowLong($script:hwnd, [Win32]::GWL_EXSTYLE)
    $newExStyle = [IntPtr]($exStyle.ToInt64() -bor [Win32]::WS_EX_TOOLWINDOW -bor [Win32]::WS_EX_NOACTIVATE)
    [Win32]::SetWindowLong($script:hwnd, [Win32]::GWL_EXSTYLE, $newExStyle) | Out-Null

    # Reassert HWND_TOPMOST over taskbar
    [Win32]::SetWindowPos($script:hwnd, [Win32]::HWND_TOPMOST, 0, 0, 0, 0,
        [Win32]::SWP_NOMOVE -bor [Win32]::SWP_NOSIZE -bor [Win32]::SWP_NOACTIVATE -bor [Win32]::SWP_SHOWWINDOW) | Out-Null
})

# ------------------------------------------------------------------------------
# 10. Live Network Speed Measurement & Updates
# ------------------------------------------------------------------------------
function Get-TargetInterfaces {
    $all = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
    
    # 1. 'All' mode: sum across all active non-loopback/tunnel interfaces
    if ($script:Config.Adapter -eq 'All') {
        return @($all | Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -notin 'Loopback', 'Tunnel' })
    }

    # 2. Specific adapter selected by name or ID
    if ($script:Config.Adapter -and $script:Config.Adapter -ne 'Auto') {
        $matched = @($all | Where-Object { ($_.Name -eq $script:Config.Adapter -or $_.Id -eq $script:Config.Adapter) -and $_.OperationalStatus -eq 'Up' })
        if ($matched.Count -gt 0) { return $matched }
        return @()
    }

    # 3. 'Auto' mode: intelligent active internet adapter discovery
    # Exclude common virtual adapters (Hyper-V, WSL, VMware, VirtualBox, TAP, Tailscale, ZeroTier, etc.)
    $candidates = @()
    foreach ($n in $all) {
        if ($n.OperationalStatus -eq 'Up' -and $n.NetworkInterfaceType -notin 'Loopback', 'Tunnel') {
            $isVirtual = $n.Description -match 'Virtual|vEthernet|Hyper-V|VMware|VirtualBox|WSL|TAP|Tailscale|ZeroTier|Npcap|WFP'
            try {
                $gw = $n.GetIPProperties().GatewayAddresses | Where-Object { 
                    $_.Address.ToString() -ne '0.0.0.0' -and $_.Address.ToString() -ne '::' 
                }
                if ($gw -and -not $isVirtual) {
                    # Optimal: active physical adapter with an active gateway
                    return @($n)
                }
                if ($gw) {
                    $candidates += @{ Iface = $n; Priority = 2 }
                } elseif (-not $isVirtual) {
                    $candidates += @{ Iface = $n; Priority = 1 }
                } else {
                    $candidates += @{ Iface = $n; Priority = 0 }
                }
            } catch {
                $candidates += @{ Iface = $n; Priority = 0 }
            }
        }
    }

    if ($candidates.Count -gt 0) {
        $best = ($candidates | Sort-Object Priority -Descending)[0]
        return @($best.Iface)
    }

    return @()
}

function Get-NetworkTotals {
    $rx = 0L; $tx = 0L
    $interfaces = Get-TargetInterfaces
    foreach ($n in $interfaces) {
        try {
            $s = $n.GetIPStatistics()
            $rx += $s.BytesReceived
            $tx += $s.BytesSent
        } catch {
            try {
                $s = $n.GetIPv4Statistics()
                $rx += $s.BytesReceived
                $tx += $s.BytesSent
            } catch { }
        }
    }
    return @($rx, $tx)
}

function Format-DataSize([long]$bytes) {
    if ($bytes -ge 1TB) {
        return ('{0:N2} TB' -f ($bytes / 1TB))
    } elseif ($bytes -ge 1GB) {
        return ('{0:N2} GB' -f ($bytes / 1GB))
    } elseif ($bytes -ge 1MB) {
        return ('{0:N1} MB' -f ($bytes / 1MB))
    } elseif ($bytes -ge 1KB) {
        return ('{0:N0} KB' -f ($bytes / 1KB))
    } else {
        return ('{0:N0} B' -f $bytes)
    }
}

function Format-Speed([double]$bytesPerSec) {
    if ($script:Config.SpeedUnit -eq 'Bits') {
        $bps = $bytesPerSec * 8
        if ($bps -ge 1000000000) {
            return @{ Val = ('{0:N2}' -f ($bps / 1000000000)); Unit = ' Gbps' }
        } elseif ($bps -ge 100000000) {
            return @{ Val = ('{0:N0}' -f ($bps / 1000000)); Unit = ' Mbps' }
        } elseif ($bps -ge 10000000) {
            return @{ Val = ('{0:N1}' -f ($bps / 1000000)); Unit = ' Mbps' }
        } elseif ($bps -ge 1000000) {
            return @{ Val = ('{0:N2}' -f ($bps / 1000000)); Unit = ' Mbps' }
        } elseif ($bps -ge 100000) {
            return @{ Val = ('{0:N0}' -f ($bps / 1000)); Unit = ' Kbps' }
        } elseif ($bps -ge 1000) {
            return @{ Val = ('{0:N1}' -f ($bps / 1000)); Unit = ' Kbps' }
        } else {
            return @{ Val = '0.0'; Unit = ' Kbps' }
        }
    } else {
        if ($bytesPerSec -ge 1GB) {
            return @{ Val = ('{0:N2}' -f ($bytesPerSec / 1GB)); Unit = ' GB/s' }
        } elseif ($bytesPerSec -ge 10MB) {
            return @{ Val = ('{0:N1}' -f ($bytesPerSec / 1MB)); Unit = ' MB/s' }
        } elseif ($bytesPerSec -ge 1MB) {
            return @{ Val = ('{0:N2}' -f ($bytesPerSec / 1MB)); Unit = ' MB/s' }
        } elseif ($bytesPerSec -ge 100KB) {
            return @{ Val = ('{0:N0}' -f ($bytesPerSec / 1KB)); Unit = ' KB/s' }
        } elseif ($bytesPerSec -ge 1KB) {
            return @{ Val = ('{0:N1}' -f ($bytesPerSec / 1KB)); Unit = ' KB/s' }
        } else {
            return @{ Val = '0.0'; Unit = ' KB/s' }
        }
    }
}

$script:sessionRxBytes = 0L
$script:sessionTxBytes = 0L
$script:prevTotals     = Get-NetworkTotals
$script:stopwatch      = [System.Diagnostics.Stopwatch]::StartNew()
$script:tickCounter    = 0

$script:pingObj        = [System.Net.NetworkInformation.Ping]::new()
$script:pingTask       = $null
$script:currentPing    = $null

$script:cachedSsid     = $null
$script:lastSsidCheck  = [DateTime]::MinValue

function Get-WifiSsid {
    if ([DateTime]::Now.Subtract($script:lastSsidCheck).TotalSeconds -lt 10 -and $null -ne $script:cachedSsid) {
        return $script:cachedSsid
    }
    $script:lastSsidCheck = [DateTime]::Now
    try {
        $lines = (netsh wlan show interfaces) | Where-Object { $_ -match '^\s*SSID\s*:' }
        if ($lines) {
            $script:cachedSsid = ($lines[0] -split ':', 2)[1].Trim()
            return $script:cachedSsid
        }
    } catch { }
    $script:cachedSsid = ''
    return ''
}

$script:historyDown = New-Object 'System.Collections.Generic.List[double]'
$script:historyUp   = New-Object 'System.Collections.Generic.List[double]'

function Update-Sparkline([double]$rx, [double]$tx) {
    $script:historyDown.Add($rx)
    $script:historyUp.Add($tx)
    if ($script:historyDown.Count -gt 30) { $script:historyDown.RemoveAt(0) }
    if ($script:historyUp.Count -gt 30)   { $script:historyUp.RemoveAt(0) }

    if (-not $tipGraphDown -or -not $tipGraphUp) { return }

    $maxVal = 10240.0 # Min 10 KB/s scale
    foreach ($v in $script:historyDown) { if ($v -gt $maxVal) { $maxVal = $v } }
    foreach ($v in $script:historyUp)   { if ($v -gt $maxVal) { $maxVal = $v } }

    $w = 210.0
    $h = 34.0
    $n = $script:historyDown.Count
    if ($n -lt 2) { return }

    $ptsDown = New-Object System.Windows.Media.PointCollection
    $ptsUp   = New-Object System.Windows.Media.PointCollection

    for ($i = 0; $i -lt $n; $i++) {
        $x = ($i / [Math]::Max(1, $n - 1)) * $w
        $yD = $h - (($script:historyDown[$i] / $maxVal) * ($h - 4)) - 2
        $yU = $h - (($script:historyUp[$i] / $maxVal) * ($h - 4)) - 2
        $ptsDown.Add((New-Object System.Windows.Point($x, [Math]::Max(2, $yD))))
        $ptsUp.Add((New-Object System.Windows.Point($x, [Math]::Max(2, $yU))))
    }

    $tipGraphDown.Points = $ptsDown
    $tipGraphUp.Points   = $ptsUp

    if ($tipGraphPeak) {
        $fmtPeak = Format-Speed $maxVal
        $tipGraphPeak.Text = "Peak: $($fmtPeak.Val)$($fmtPeak.Unit)"
    }
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds($script:Config.IntervalMs)

$timer.Add_Tick({
    $now = Get-NetworkTotals
    $elapsedSec = $script:stopwatch.Elapsed.TotalSeconds
    $script:stopwatch.Restart()

    if ($elapsedSec -le 0) { $elapsedSec = 1.0 }

    # Compute delta bytes transferred in this interval
    $deltaRx = [Math]::Max(0L, ($now[0] - $script:prevTotals[0]))
    $deltaTx = [Math]::Max(0L, ($now[1] - $script:prevTotals[1]))
    $script:sessionRxBytes += $deltaRx
    $script:sessionTxBytes += $deltaTx

    $dRx = [Math]::Max(0, $deltaRx / $elapsedSec)
    $dTx = [Math]::Max(0, $deltaTx / $elapsedSec)
    $script:prevTotals = $now

    $fmtDown = Format-Speed $dRx
    $fmtUp   = Format-Speed $dTx

    # Update Stacked Elements
    $valDownStacked.Text  = $fmtDown.Val
    $unitDownStacked.Text = $fmtDown.Unit
    $valUpStacked.Text    = $fmtUp.Val
    $unitUpStacked.Text   = $fmtUp.Unit

    # Update Inline Elements
    $valDownInline.Text   = $fmtDown.Val
    $unitDownInline.Text  = $fmtDown.Unit
    $valUpInline.Text     = $fmtUp.Val
    $unitUpInline.Text    = $fmtUp.Unit

    # Update 30-Second Sparkline History
    Update-Sparkline $dRx $dTx

    # Asynchronous Non-Blocking Ping (every ~2 seconds)
    $script:tickCounter++
    if ($script:tickCounter % 2 -eq 0) {
        if ($null -eq $script:pingTask -or $script:pingTask.IsCompleted) {
            if ($null -ne $script:pingTask -and $script:pingTask.IsCompleted -and -not $script:pingTask.IsFaulted) {
                try {
                    $reply = $script:pingTask.Result
                    if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                        $script:currentPing = [int]$reply.RoundtripTime
                    } else {
                        $script:currentPing = -1
                    }
                } catch {
                    $script:currentPing = -1
                }
            }
            try {
                $script:pingTask = $script:pingObj.SendPingAsync('1.1.1.1', 800)
            } catch { }
        }
    }

    # Update Tooltip Card
    if ($tipSessionDown) {
        $tipSessionDown.Text = Format-DataSize $script:sessionRxBytes
        $tipSessionUp.Text   = Format-DataSize $script:sessionTxBytes
        $tipLiveSpeed.Text   = ('{0}{1} ' + [char]0x2193 + '  {2}{3} ' + [char]0x2191) -f $fmtDown.Val, $fmtDown.Unit, $fmtUp.Val, $fmtUp.Unit

        if ($null -eq $script:currentPing) {
            $tipPingText.Text = 'Checking...'
            $tipPingDot.Fill  = $brushConverter.ConvertFromString('#808080')
        } elseif ($script:currentPing -lt 0) {
            $tipPingText.Text = 'Offline'
            $tipPingDot.Fill  = $brushConverter.ConvertFromString('#FF4D4D')
        } else {
            $tipPingText.Text = "$($script:currentPing) ms"
            if ($script:currentPing -lt 80) {
                $tipPingDot.Fill = $brushConverter.ConvertFromString('#38E1B0')
            } elseif ($script:currentPing -lt 150) {
                $tipPingDot.Fill = $brushConverter.ConvertFromString('#FFA447')
            } else {
                $tipPingDot.Fill = $brushConverter.ConvertFromString('#FF6060')
            }
        }

        $activeIfaces = Get-TargetInterfaces
        if ($activeIfaces.Count -gt 0) {
            $iface = $activeIfaces[0]
            if ($iface.NetworkInterfaceType -eq 'Wireless80211') {
                $ssid = Get-WifiSsid
                if ($ssid) {
                    $tipAdapterName.Text = "Wi-Fi ($ssid)"
                } else {
                    $tipAdapterName.Text = "Wi-Fi ($($iface.Name))"
                }
            } else {
                $tipAdapterName.Text = "$($iface.Name) (Ethernet)"
            }

            # Retrieve Local IP and Gateway
            try {
                $u = $iface.GetIPProperties().UnicastAddresses | 
                    Where-Object { $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork }
                $ipStr = if ($u) { $u[0].Address.ToString() } else { '--' }

                $g = $iface.GetIPProperties().GatewayAddresses | 
                    Where-Object { $_.Address.ToString() -ne '0.0.0.0' -and $_.Address.ToString() -ne '::' }
                $gwStr = if ($g) { $g[0].Address.ToString() } else { '--' }

                if ($tipIpGateway) {
                    $tipIpGateway.Text = "$ipStr / $gwStr"
                }
            } catch { }
        } else {
            $tipAdapterName.Text = 'Disconnected'
            if ($tipIpGateway) { $tipIpGateway.Text = '-- / --' }
        }
    }

    # Maintain Z-Order on top of taskbar (every ~3 seconds)
    if ($script:tickCounter % 3 -eq 0 -and $script:hwnd -ne [IntPtr]::Zero) {
        [Win32]::SetWindowPos($script:hwnd, [Win32]::HWND_TOPMOST, 0, 0, 0, 0,
            [Win32]::SWP_NOMOVE -bor [Win32]::SWP_NOSIZE -bor [Win32]::SWP_NOACTIVATE -bor [Win32]::SWP_SHOWWINDOW) | Out-Null
    }
})

$timer.Start()

# Run the WPF Application
[System.Windows.Application]::new().Run($win) | Out-Null
