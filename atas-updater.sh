
export WINEPREFIX="${WINEPREFIX:-$HOME/.local/share/wineprefixes/atas}"
export WINEARCH=win64
export WINEDEBUG="-all"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="" WINE_WAYLAND_DISPLAY=""
export XAUTHORITY="${XAUTHORITY}"
export PATH="@wineBin@/bin:@winetricks@/bin:$PATH"
export LD_LIBRARY_PATH="@nss@/lib:@gnutls@/lib:@vulkanLoader@/lib:@libGL@/lib:@freetype@/lib:@fontconfig@/lib:@libpng@/lib:@zlib@/lib:@bzip2@/lib:@brotli@/lib:@expat@/lib:@wayland@/lib:@libdecor@/lib:@libxkbcommon@/lib:@libX11@/lib:@libXext@/lib:@pkgsi686Freetype@/lib:@pkgsi686Fontconfig@/lib:@pkgsi686Libpng@/lib:@pkgsi686Zlib@/lib:@pkgsi686Bzip2@/lib:@pkgsi686Brotli@/lib:@pkgsi686Expat@/lib:@pkgsi686Wayland@/lib:@pkgsi686Libdecor@/lib:@pkgsi686Libxkbcommon@/lib:@pkgsi686Libx11@/lib:@pkgsi686Libxext@/lib:@wineBin@/lib/x86_64-linux-gnu:@wineBin@/lib:@wineBin@/lib/wine/x86_64-unix:@wineBin@/lib/wine/i386-unix:/run/opengl-driver/lib:/run/opengl-driver-32/lib"
export SSL_CERT_DIR="@cacert@/etc/ssl/certs"
export WINEDLLOVERRIDES="mscoree=b;dwrite=b;gdiplus=b"
EXE_PATH=$(find "$WINEPREFIX/drive_c/Program Files" -name "OFT.Platform.Updater.exe" 2>/dev/null | head -n 1)
[ -z "$EXE_PATH" ] && EXE_PATH=$(find "$WINEPREFIX/drive_c" -name "OFT.Platform.Updater.exe" 2>/dev/null | head -n 1)
[ -n "$EXE_PATH" ] && exec wine "$EXE_PATH" "$@" || echo "Updater not found"
        ''