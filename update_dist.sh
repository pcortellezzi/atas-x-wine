#!/usr/bin/env bash
set -e

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "========================================="
echo "  ATAS-X-Wine: Rebuilding dist/ package"
echo "========================================="

# 1. Build launcher and hook DLL from Nix
echo "[1/3] Compiling launcher and hook DLL via Nix..."
nix build .#atas-launcher --no-link
nix build .#window-hider-hook --no-link

# Get Nix store paths
LAUNCHER_STORE=$(nix eval --raw .#atas-launcher.outPath)
HOOK_STORE=$(nix eval --raw .#window-hider-hook.outPath)

# Copy the Windows binaries to dist/
echo "[2/3] Deploying compiled binaries to dist/..."
mkdir -p dist
cp -f "$LAUNCHER_STORE/bin/atas_launcher.exe" dist/
cp -f "$HOOK_STORE/lib/window_hider_hook.dll" dist/

# 2. Translate atas.sh to generic dist/atas.sh
echo "[3/3] Translating template scripts to generic Linux shell scripts..."
sed -e 's|@wineBin@/bin:@winetricks@/bin:|/usr/bin:|g' \
    -e 's|@wineBin@|$PROTON_DIR|g' \
    -e 's|export LD_LIBRARY_PATH=.*|export LD_LIBRARY_PATH="$PROTON_DIR/lib:$PROTON_DIR/lib64:$LD_LIBRARY_PATH"|g' \
    -e 's|@cacert@/etc/ssl/certs|/etc/ssl/certs|g' \
    -e 's|@windowHiderHook@/lib/window_hider_hook.dll|$INSTALL_DIR/window_hider_hook.dll|g' \
    -e 's|@atasLauncher@/bin/atas_launcher.exe|$INSTALL_DIR/atas_launcher.exe|g' \
    atas.sh > dist/atas.sh
chmod +x dist/atas.sh

# Translate atas-updater.sh to generic dist/atas-updater.sh
sed -e 's|@wineBin@/bin:@winetricks@/bin:|/usr/bin:|g' \
    -e 's|@wineBin@|$PROTON_DIR|g' \
    -e 's|export LD_LIBRARY_PATH=.*|export LD_LIBRARY_PATH="$PROTON_DIR/lib:$PROTON_DIR/lib64:$LD_LIBRARY_PATH"|g' \
    -e 's|@cacert@/etc/ssl/certs|/etc/ssl/certs|g' \
    atas-updater.sh > dist/atas-updater.sh
chmod +x dist/atas-updater.sh

echo "-----------------------------------------"
echo "  Success! The dist/ package is updated."
echo "========================================="
