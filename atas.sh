
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/wineprefixes/atas}"
export WINEARCH=win64
export WINEDEBUG="${WINEDEBUG:--all}"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export DISPLAY="${DISPLAY:-:0}"
export WINE_WAYLAND_DISPLAY="${WINE_WAYLAND_DISPLAY:-${WAYLAND_DISPLAY}}"
export XAUTHORITY="${XAUTHORITY}"
export PATH="@wineBin@/bin:@winetricks@/bin:$PATH"
export LD_LIBRARY_PATH="@nss@/lib:@gnutls@/lib:@vulkanLoader@/lib:@libGL@/lib:@freetype@/lib:@fontconfig@/lib:@libpng@/lib:@zlib@/lib:@bzip2@/lib:@brotli@/lib:@expat@/lib:@wayland@/lib:@libdecor@/lib:@libxkbcommon@/lib:@libX11@/lib:@libXext@/lib:@pkgsi686Freetype@/lib:@pkgsi686Fontconfig@/lib:@pkgsi686Libpng@/lib:@pkgsi686Zlib@/lib:@pkgsi686Bzip2@/lib:@pkgsi686Brotli@/lib:@pkgsi686Expat@/lib:@pkgsi686Wayland@/lib:@pkgsi686Libdecor@/lib:@pkgsi686Libxkbcommon@/lib:@pkgsi686Libx11@/lib:@pkgsi686Libxext@/lib:@wineBin@/lib/x86_64-linux-gnu:@wineBin@/lib:@wineBin@/lib/wine/x86_64-unix:@wineBin@/lib/wine/i386-unix:/run/opengl-driver/lib:/run/opengl-driver-32/lib"
export SSL_CERT_DIR="@cacert@/etc/ssl/certs"
 # Force integrated AMD Radeon GPU usage (bypasses Nvidia hybrid offload bugs)
 export VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json"
 export VK_DRIVER_FILES="/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json"
 export __NV_PRIME_RENDER_OFFLOAD=0
 export __GLX_VENDOR_LIBRARY_NAME=mesa
  export AVALONIA_RENDERER=vulkan WINEFSYNC=1 WINEESYNC=1
 export WINEDLLOVERRIDES="mscoree=b;mshtml=b;wmiutils=b;wbemprox=b;uiautomationcore=d;oleacc=d;dwrite=b"
export WINE_X11_NO_MITSHM=1
export DXVK_CONFIG="dxgi.maxDeviceMemory=0;dxvk.allowMemoryOvercommit=True;dxgi.syncInterval=0;dxgi.numBackBuffers=3;dxvk.enableAsync=True;dxgi.nvapiHack=False;dxvk.numCompilerThreads=0;dxgi.enableDummyCompositionSwapchain=True"
export ANGLE_DEFAULT_PLATFORM=d3d11
export DOTNET_SYSTEM_GLOBALIZATION_USENLS=1
GUID="6F88E200-A973-11EE-8C90-0800200C9A66"

if [ -z "$(find "$WINEPREFIX/drive_c/Program Files" -name 'OFT.Platform*.exe' 2>/dev/null | head -1)" ] && [ ! -d "$WINEPREFIX/drive_c/Program Files/ATAS" ] 2>/dev/null; then
  echo "=== Installation ATAS ==="
  INSTALLER=""
  if [ -n "$1" ] && [ -f "$1" ]; then
    INSTALLER="$1"
  elif [ "$1" = "--install" ]; then
    shift
    [ -n "$1" ] && [ -f "$1" ] && INSTALLER="$1"
  fi
  if [ -z "$INSTALLER" ]; then
    if command -v zenity >/dev/null 2>&1; then
      if zenity --question --title="ATAS X" --text="ATAS n'est pas installé.\nVoulez-vous ouvrir le site atas.net pour télécharger l'installeur ?" \
        --ok-label="Ouvrir le site" --cancel-label="Choisir un fichier" 2>/dev/null; then
        xdg-open "https://atas.net" 2>/dev/null
      fi
      INSTALLER=$(zenity --file-selection --title="Sélectionnez ATAS_Setup.exe" --file-filter="*.exe" 2>/dev/null)
    elif command -v kdialog >/dev/null 2>&1; then
      if kdialog --yesno "ATAS n'est pas installé.\nVoulez-vous ouvrir le site atas.net pour télécharger l'installeur ?" 2>/dev/null; then
        xdg-open "https://atas.net" 2>/dev/null
      fi
      INSTALLER=$(kdialog --getopenfilename . "*.exe" --title "Sélectionnez ATAS_Setup.exe" 2>/dev/null)
    else
      echo "ATAS n'est pas installé."
      echo "Téléchargez l'installeur depuis https://atas.net"
      echo "Puis exécutez : atas /chemin/vers/ATAS_Setup.exe"
      exit 1
    fi
  fi
  if [ -z "$INSTALLER" ] || [ ! -f "$INSTALLER" ]; then
    echo "Aucun installeur sélectionné."
    exit 1
  fi
  echo "Installeur : $INSTALLER"
  pkill -9 -f "wineserver|winedevice|explorer.exe|services.exe|rpcss.exe" || true
  wineserver -k || true
  rm -rf "$WINEPREFIX"/* "$WINEPREFIX"/.[!.]* 2>/dev/null || true
  mkdir -p "$WINEPREFIX"
  echo "[1/4] wine prefix..."
  wine wineboot -i 2>&1 | grep -v fixme | tail -3
  for f in libvkd3d-1.dll libvkd3d-shader-1.dll libvkd3d-utils-1.dll; do
    [ -f "$WINEPREFIX/drive_c/windows/system32/$f" ] || cp "@wineBin@/share/default_pfx/drive_c/windows/system32/$f" "$WINEPREFIX/drive_c/windows/system32/" 2>/dev/null || true
  done
  echo "[2/4] prerequisites..."
  winetricks -q vcrun2022 dotnetdesktop8 winhttp d3dcompiler_47 corefonts 2>&1 | grep -v fixme | tail -5
  cat << 'REGEOF' > "$WINEPREFIX/wmi_com_fix.reg"
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
REGEOF
  echo "[3/4] HWID spoofing..."
  wine regedit /C "$WINEPREFIX/wmi_com_fix.reg" 2>&1 | grep -v fixme || true
  for kv in "HKLM\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0 /v ProcessorId /t REG_SZ /d BFEBFBFF000B0671" \
            "HKLM\\HARDWARE\\DEVICEMAP\\Scsi\\Scsi Port 0\\Scsi Bus 0\\Target Id 0\\Logical Unit Id 0 /v Identifier /t REG_SZ /d DISK-ATAS-SD-512GB"; do
    wine reg add $kv /f >/dev/null 2>&1 || true
  done
  echo "[4/4] installer..."
  timeout 900 wine "$INSTALLER" 2>&1 | grep -v fixme | tail -5 || true
  echo "=== Install complete ==="
  exit 0
fi

# Remove DXVK DLLs to force software rendering for the Avalonia UI, preventing black main windows
for d in system32 syswow64; do
  for dll in d3d11.dll dxgi.dll d3d9.dll d3d10core.dll dxvk_config.dll; do
    rm -f "$WINEPREFIX/drive_c/windows/$d/$dll" 2>/dev/null || true
  done
  # But keep libvkd3d for VulkanSkiaHost if it needs it
  for dll in libvkd3d-1.dll libvkd3d-shader-1.dll libvkd3d-utils-1.dll; do
    [ -f "$WINEPREFIX/drive_c/windows/$d/$dll" ] || cp "@wineBin@/share/default_pfx/drive_c/windows/$d/$dll" "$WINEPREFIX/drive_c/windows/$d/" 2>/dev/null || true
  done
done

wine reg add "HKLM\\System\\CurrentControlSet\\Control\\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 36 /f >/dev/null 2>&1
wine reg add "HKLM\\Software\\Microsoft\\Cryptography" /v MachineGuid /t REG_SZ /d "$GUID" /f >/dev/null 2>&1
wine reg add "HKLM\\HARDWARE\\Description\\System\\BIOS" /v BIOSSerialNumber /t REG_SZ /d "ATAS-SN-2026-X11" /f >/dev/null 2>&1
wine reg add "HKLM\\HARDWARE\\Description\\System\\BIOS" /v BaseBoardSerialNumber /t REG_SZ /d "MB-ATAS-998877" /f >/dev/null 2>&1
wine reg add "HKCU\\Software\\Wine\\Drivers" /v Graphics /t REG_SZ /d "wayland,x11" /f >/dev/null 2>&1
wine reg delete "HKCU\\Software\\Wine\\Explorer" /v Desktop /f >/dev/null 2>&1 || true
wine reg delete "HKCU\\Software\\Wine\\Explorer\\Desktops" /f >/dev/null 2>&1 || true

if [ "$1" == "--command" ]; then shift; exec wine "$@"; fi
if [ "$1" == "--trace" ]; then export WINEDEBUG="+winsock,+ws2_32,+iphlpapi,+winhttp,+secur32,+crypt,+module"; fi

wine net start winmgmt 2>/dev/null || true
EXE_PATH=$(find "$WINEPREFIX/drive_c/Program Files" -name "OFT.PlatformX.exe" 2>/dev/null | head -n 1)
[ -z "$EXE_PATH" ] && EXE_PATH=$(find "$WINEPREFIX/drive_c/Program Files" -name "OFT.Platform.exe" 2>/dev/null | head -n 1)
[ -z "$EXE_PATH" ] && EXE_PATH=$(find "$WINEPREFIX/drive_c" -name "ATAS*" 2>/dev/null | head -n 1)
if [ -n "$EXE_PATH" ]; then
  cp -f "@windowHiderHook@/lib/window_hider_hook.dll" "$WINEPREFIX/drive_c/window_hider_hook.dll"
  cp -f "@atasLauncher@/bin/atas_launcher.exe" "$WINEPREFIX/drive_c/atas_launcher.exe"
  wine C:\\atas_launcher.exe "$@"
else
  echo "ATAS not found"
fi
        ''