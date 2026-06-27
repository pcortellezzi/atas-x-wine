#!/usr/bin/env bash
set -e

INSTALL_DIR="$HOME/.local/share/atas-linux"
WINEPREFIX="$INSTALL_DIR/prefix"
PROTON_DIR="$INSTALL_DIR/proton"
DIST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "   ATAS Linux Standalone Installer"
echo "========================================="
echo "Target installation folder: $INSTALL_DIR"
echo "Target Wine prefix:         $WINEPREFIX"
echo "This installer will set up ATAS on generic Linux."
echo "-----------------------------------------"

# 1. System requirements checks
if [ -z "$WAYLAND_DISPLAY" ]; then
    echo "Warning: No Wayland session detected. Wayland is highly recommended for subsurface presentation fixes."
fi

# Verify dependencies are available
for cmd in wget tar python3 wine winetricks; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required system tool '$cmd' is missing. Please install it via your package manager."
        exit 1
    fi
done

mkdir -p "$INSTALL_DIR"
mkdir -p "$WINEPREFIX"

# 2. Download and extract GE-Proton11-1
if [ ! -d "$PROTON_DIR" ] || [ ! -f "$PROTON_DIR/bin/wine" ]; then
    echo "[1/6] Downloading GE-Proton11-1 (approx. 500MB)..."
    PROTON_TAR="/tmp/GE-Proton11-1.tar.gz"
    wget -O "$PROTON_TAR" "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-1/GE-Proton11-1.tar.gz"
    
    echo "Extracting Proton custom layer..."
    mkdir -p "$PROTON_DIR"
    tar -xzf "$PROTON_TAR" -C "$INSTALL_DIR"
    mv "$INSTALL_DIR/GE-Proton11-1/files"/* "$PROTON_DIR/"
    rm -rf "$INSTALL_DIR/GE-Proton11-1" "$PROTON_TAR"
    echo "Proton extracted successfully."
else
    echo "[1/6] GE-Proton11-1 already present, skipping download."
fi

# 3. Patch wbemprox.dll using Python
echo "[2/6] Patching Proton's wbemprox.dll to bypass HWID checks..."
for dll in "$PROTON_DIR/lib/wine/x86_64-windows/wbemprox.dll" "$PROTON_DIR/lib/wine/i386-windows/wbemprox.dll"; do
    if [ -f "$dll" ]; then
        python3 "$DIST_DIR/patch_wbemprox.py" "$dll"
    fi
done

# 4. Set up WINEPREFIX environment
export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG="-all"
export PATH="$PROTON_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$PROTON_DIR/lib:$PROTON_DIR/lib64:$LD_LIBRARY_PATH"

echo "[3/6] Initializing clean Wine prefix..."
pkill -9 -f "wineserver|winedevice|explorer.exe|services.exe|rpcss.exe" || true
wineserver -k || true
wine wineboot -i

# Copy VKD3D DLLs from default template
for d in system32 syswow64; do
    for f in libvkd3d-1.dll libvkd3d-shader-1.dll libvkd3d-utils-1.dll; do
        [ -f "$WINEPREFIX/drive_c/windows/$d/$f" ] || cp "$PROTON_DIR/share/default_pfx/drive_c/windows/$d/$f" "$WINEPREFIX/drive_c/windows/$d/" 2>/dev/null || true
    done
done

# 5. Winetricks dependencies installation
echo "[4/6] Installing prerequisites via winetricks..."
echo "This will install: vcrun2022, dotnetdesktop8, winhttp, d3dcompiler_47, corefonts."
echo "Please wait, this will download and install runtimes..."
winetricks -q vcrun2022 dotnetdesktop8 winhttp d3dcompiler_47 corefonts

# Remove DXVK DLLs to force software rendering for Avalonia UI (prevents black screen bugs)
for d in system32 syswow64; do
    for dll in d3d11.dll dxgi.dll d3d9.dll d3d10core.dll dxvk_config.dll; do
        rm -f "$WINEPREFIX/drive_c/windows/$d/$dll" 2>/dev/null || true
    done
done

# 6. Apply registry entries and HWID spoofing
echo "[5/6] Injecting licensing / HWID registry patches..."
cat << 'REGEOF' > "$WINEPREFIX/customizations.reg"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\CLSID\{CF4CC405-E2C5-4DDD-B3CE-5E7582D8C9FA}]
@="WbemDefPath"
[HKEY_CLASSES_ROOT\CLSID\{CF4CC405-E2C5-4DDD-B3CE-5E7582D8C9FA}\InprocServer32]
@="C:\\windows\\system32\\wbem\\wmiutils.dll"
"ThreadingModel"="Both"

[HKEY_LOCAL_MACHINE\Software\Classes\CLSID\{CF4CC405-E2C5-4DDD-B3CE-5E7582D8C9FA}]
@="WbemDefPath"
[HKEY_LOCAL_MACHINE\Software\Classes\CLSID\{CF4CC405-E2C5-4DDD-B3CE-5E7582D8C9FA}\InprocServer32]
@="C:\\windows\\system32\\wbem\\wmiutils.dll"
"ThreadingModel"="Both"

[HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\PriorityControl]
"Win32PrioritySeparation"=dword:00000024

[HKEY_LOCAL_MACHINE\Software\Microsoft\Cryptography]
"MachineGuid"="6F88E200-A973-11EE-8C90-0800200C9A66"

[HKEY_LOCAL_MACHINE\HARDWARE\Description\System\BIOS]
"BIOSSerialNumber"="ATAS-SN-2026-X11"
"BaseBoardSerialNumber"="MB-ATAS-998877"

[HKEY_CURRENT_USER\Software\Wine\Drivers]
"Graphics"="wayland,x11"
REGEOF

wine regedit /C "$WINEPREFIX/customizations.reg"
rm -f "$WINEPREFIX/customizations.reg"

wine reg add "HKLM\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0" /v ProcessorId /t REG_SZ /d "BFEBFBFF000B0671" /f >/dev/null 2>&1
wine reg add "HKLM\\HARDWARE\\DEVICEMAP\\Scsi\\Scsi Port 0\\Scsi Bus 0\\Target Id 0\\Logical Unit Id 0" /v Identifier /t REG_SZ /d "DISK-ATAS-SD-512GB" /f >/dev/null 2>&1

# Deploy C++ Hook and Launcher
cp -f "$DIST_DIR/window_hider_hook.dll" "$WINEPREFIX/drive_c/"
cp -f "$DIST_DIR/atas_launcher.exe" "$WINEPREFIX/drive_c/"

# 7. Run Windows ATAS installer if supplied
if [ -f "$1" ]; then
    echo "[6/6] Executing ATAS Windows installer..."
    # Convert Unix path to Wine drive Z path
    ABS_PATH=$(realpath "$1")
    wine C:\\atas_launcher.exe "Z:$ABS_PATH"
else
    echo "[6/6] No installer file supplied. Skip program installation step."
    echo "To install ATAS later, run: ./install_atas.sh /path/to/ATAS_Setup.exe"
fi

# Create launch script
cat << 'RUNEOF' > "$INSTALL_DIR/atas.sh"
#!/usr/bin/env bash
INSTALL_DIR="$HOME/.local/share/atas-linux"
WINEPREFIX="$INSTALL_DIR/prefix"
PROTON_DIR="$INSTALL_DIR/proton"

export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG="-all"
export PATH="$PROTON_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$PROTON_DIR/lib:$PROTON_DIR/lib64:$LD_LIBRARY_PATH"
export AVALONIA_RENDERER=vulkan WINEFSYNC=1 WINEESYNC=1
export WINEDLLOVERRIDES="mscoree=b;mshtml=b;wmiutils=b;wbemprox=b;uiautomationcore=d;oleacc=d;dwrite=b"
export DOTNET_SYSTEM_GLOBALIZATION_USENLS=1

# Locate ATAS executable in prefix
EXE_PATH=$(find "$WINEPREFIX/drive_c/Program Files" -name "OFT.Platform.exe" 2>/dev/null | head -n 1)
[ -z "$EXE_PATH" ] && EXE_PATH=$(find "$WINEPREFIX/drive_c" -name "ATAS*" 2>/dev/null | head -n 1)

if [ -n "$EXE_PATH" ]; then
    # Refresh Hook DLL and Launcher versions
    cp -f "$INSTALL_DIR/window_hider_hook.dll" "$WINEPREFIX/drive_c/" 2>/dev/null || true
    cp -f "$INSTALL_DIR/atas_launcher.exe" "$WINEPREFIX/drive_c/" 2>/dev/null || true
    
    exec wine C:\\atas_launcher.exe "$@"
else
    echo "Error: ATAS executable not found."
    echo "Please run install_atas.sh with the ATAS setup executable to install the application."
fi
RUNEOF
chmod +x "$INSTALL_DIR/atas.sh"

# Create updater launch script
cat << 'RUNEOF' > "$INSTALL_DIR/atas-updater.sh"
#!/usr/bin/env bash
INSTALL_DIR="$HOME/.local/share/atas-linux"
WINEPREFIX="$INSTALL_DIR/prefix"
PROTON_DIR="$INSTALL_DIR/proton"

export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG="-all"
export PATH="$PROTON_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$PROTON_DIR/lib:$PROTON_DIR/lib64:$LD_LIBRARY_PATH"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="" WINE_WAYLAND_DISPLAY=""
export WINEDLLOVERRIDES="mscoree=b;mshtml=b;wmiutils=b;wbemprox=b;uiautomationcore=d;oleacc=d;dwrite=b"

# Find ATAS Updater executable in prefix
EXE_PATH=$(find "$WINEPREFIX/drive_c/Program Files" -name "OFT.Platform.Updater.exe" 2>/dev/null | head -n 1)
[ -z "$EXE_PATH" ] && EXE_PATH=$(find "$WINEPREFIX/drive_c" -name "OFT.Platform.Updater.exe" 2>/dev/null | head -n 1)

if [ -n "$EXE_PATH" ]; then
    exec wine "$EXE_PATH" "$@"
else
    echo "Error: ATAS Updater executable not found."
fi
RUNEOF
chmod +x "$INSTALL_DIR/atas-updater.sh"

# Copy hooks to local installation folder for persistence
cp -f "$DIST_DIR/window_hider_hook.dll" "$INSTALL_DIR/"
cp -f "$DIST_DIR/atas_launcher.exe" "$INSTALL_DIR/"

echo "-----------------------------------------"
echo "   ATAS Linux setup complete!"
echo "-----------------------------------------"
echo "You can now launch ATAS at any time using:"
echo "  $INSTALL_DIR/atas.sh"
echo "========================================="
