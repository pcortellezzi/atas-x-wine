
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/wineprefixes/atas}"
export WINEARCH=win64
export WINEDEBUG="-all"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="" WINE_WAYLAND_DISPLAY=""
export XAUTHORITY="${XAUTHORITY}"
export PATH="/usr/bin:$PATH"
export LD_LIBRARY_PATH="$PROTON_DIR/lib:$PROTON_DIR/lib64:$LD_LIBRARY_PATH"
export SSL_CERT_DIR="/etc/ssl/certs"
export WINEDLLOVERRIDES="mscoree=b;dwrite=b;gdiplus=b"
EXE_PATH=$(find "$WINEPREFIX/drive_c/Program Files" -name "OFT.Platform.Updater.exe" 2>/dev/null | head -n 1)
[ -z "$EXE_PATH" ] && EXE_PATH=$(find "$WINEPREFIX/drive_c" -name "OFT.Platform.Updater.exe" 2>/dev/null | head -n 1)
[ -n "$EXE_PATH" ] && exec wine "$EXE_PATH" "$@" || echo "Updater not found"