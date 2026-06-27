# Standalone Distribution & Installation Guide for ATAS under Linux

This guide details how to install and run the **ATAS** trading platform on any Linux distribution (Ubuntu, Arch, Debian, Fedora, etc.) with synchronous Vulkan subsurface hiding under Wayland.

---

## 📋 System Requirements

To ensure smooth installation and graphics rendering:
1. **Active Wayland session** (KDE Plasma Wayland or GNOME Wayland). Wine's native Wayland driver (`winewayland.drv`) is used for windowing.
2. **Vulkan drivers installed** and configured for your GPU (Mesa RADV for AMD, official NVIDIA driver for NVIDIA).
3. **Required system utilities**:
   - `wget` and `tar` (for downloading and extracting Proton).
   - `python3` (for automatically applying motherboard / HWID spoofing patches).
   - `winetricks` (for automated installation of Windows software dependencies).
   - `wine` (a system-wide Wine version installed to register binary loaders).

---

## 📦 Package Contents

The `dist/` directory contains all pre-compiled assets and automated launch scripts:
* [install_atas.sh](file:///home/philippe/Projects/ATAS/dist/install_atas.sh): The prefix initialization and automated setup shell script.
* [atas_launcher.exe](file:///home/philippe/Projects/ATAS/dist/atas_launcher.exe): Our C++ suspended-state remote thread injection launcher (static binary).
* [window_hider_hook.dll](file:///home/philippe/Projects/ATAS/dist/window_hider_hook.dll): Our C++ Hook DLL that intercepts `SetWindowPos` and `DeferWindowPos` to cleanly hide inactive charts under Wayland.
* [patch_wbemprox.py](file:///home/philippe/Projects/ATAS/dist/patch_wbemprox.py): Python script that patches HWID / registry endpoints inside Proton's DLL files.

---

## 🛠 Installation Procedure

1. Open a terminal in the folder containing `install_atas.sh` and the ATAS Windows installer (e.g., `ATAS_Setup.exe`).
2. Make the installer script executable:
   ```bash
   chmod +x install_atas.sh
   ```
3. Run the installation script, passing the path of the ATAS setup executable as an argument:
   ```bash
   ./install_atas.sh /path/to/ATAS_Setup.exe
   ```

### What does the installation script do?
1. **Verifies and configures Proton**: Automatically downloads `GE-Proton11-1`, extracts it, and applies the HWID spoofing binary patch on `wbemprox.dll` to ensure licensing checks pass.
2. **Initializes the WINEPREFIX**: Creates an isolated 64-bit Wine prefix under `~/.local/share/atas-linux/prefix`.
3. **Installs Windows Dependencies**: Silently calls `winetricks` to fetch and configure:
   - `vcrun2022` (Microsoft Visual C++ runtimes).
   - `dotnetdesktop8` (.NET 8 Desktop Runtime).
   - `winhttp` and `d3dcompiler_47` (required by the rendering engine).
   - `corefonts` (standard Windows fonts).
4. **Applies Registry Customizations**: Configures the Wine registry to prioritize Wayland windowing, spoofs hardware serials (CPU, disks, BIOS), and registers the WMI COM workaround.
5. **Deploys Hook DLLs**: Configures the memory injection launcher to bypass Wayland subsurface bugs.
6. **Starts the ATAS installer**.

---

## 🚀 Launching ATAS

Once installed, you can start ATAS at any time using the generated launcher script:
```bash
~/.local/share/atas-linux/atas.sh
```

This script sets up all required graphics variables for ATAS's Vulkan/Skia engine (e.g. `AVALONIA_RENDERER=vulkan`, `WINEFSYNC=1`, etc.) and runs the application cleanly.
