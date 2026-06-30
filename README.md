# atas-x-wine

Compatibility and integration layer to run the **ATAS X** trading platform under Linux via Wine/Proton and Wayland.

---

## 🚀 Features
* **Synchronous C++ DLL Hook**: Intercepts `SetWindowPos` and `DeferWindowPos` system calls to cleanly hide inactive Vulkan presentation subsurfaces.
* **Remote Thread Injection Launcher**: Starts ATAS and injects the Hook DLL into memory prior to display initialization.
* **HWID / WMI Spoofing**: Bypasses motherboard and drive serial number validation checks for license activation.
* **No Gamescope Required**: Runs directly on your native Wayland compositor (KDE Plasma, GNOME, etc.).

---

## 🛠 Project Structure
* `flake.nix`: NixOS package definition that cross-compiles C++ targets and configures the Wine prefix.
* `atas_launcher.cpp`: C++ source code for the remote thread injection suspended-state launcher (Windows 64-bit).
* `window_hider_hook.cpp`: C++ source code for the Win32 Hook DLL to handle window visibility routing.
* `dist/`: Universal standalone package for other Linux distributions (Ubuntu, Arch, etc.).
  - `install_atas.sh`: Automatic installation and bootstrapper script (downloads Proton, runs winetricks, patches DLLs).
  - `DISTRIBUTION_GUIDE.md`: Comprehensive installation guide for non-NixOS platforms.

---

## 📦 Usage under NixOS / Nix Flakes

### 1. Enter the development shell
```bash
nix develop
```

### 2. Initial ATAS installation
Download the official ATAS installer (`ATAS_Setup.exe`), then run:
```bash
atas --install /path/to/ATAS_Setup.exe
```

### 3. Run ATAS
Once installed, simply start the application with:
```bash
atas
```

### 4. Update ATAS
```bash
atas-updater
```

---

## 🐧 Usage on other distributions (Ubuntu, Arch, Fedora)

See the detailed guide [dist/DISTRIBUTION_GUIDE.md](dist/DISTRIBUTION_GUIDE.md) to install the application outside NixOS using our universal standalone package.

---

## 🖥️ Wayland & Multi-Monitor Drag & Drop Notes

Due to the security design of the **Wayland** protocol, absolute screen coordinates are hidden from client applications. Wine has no native way to determine the absolute spatial relationship between windows positioned by the compositor (e.g. KWin).

To make window interactions and docking usable under Wayland, the hook DLL implements several low-level workarounds:
1. **Dynamic Monitor Tracking**: Matches active window positions virtualized in Wine to the physical monitor offset (`0` or `1920`) based on active foreground interactions.
2. **Hook-Based Mouse Redirection**: Redirects low-level mouse messages to the drag source window using custom atomic pointer detours on `SetCapture`, `ReleaseCapture`, and `GetCapture` in `user32.dll`.
3. **Background Suppression**: Blocks cursor and focus activation messages on background windows while dragging to prevent them from hijacking mouse capture.

### Known Limitations under Wayland:
* **Intra-window Drag & Drop**: Fully supported. Widgets can be rearranged inside their parent windows. Drop preview overlays may show minor alignment offsets, but drop placement is accurate.
* **Inter-window Drag & Drop**: Not supported. Due to Wayland's isolated surface architecture, dragging widgets *between* separate top-level windows will not resolve coordinates correctly. Use separate windows as independent workspaces.

