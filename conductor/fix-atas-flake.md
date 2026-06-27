# Plan for ATAS X Wine Integration

## Objective
Update the `flake.nix` to become the single source of truth for running ATAS X under Wine on NixOS. This will resolve the "Mono vs .NET" battle by properly installing the .NET Desktop runtime via `winetricks` and explicitly disabling Wine-Mono, while retaining the essential DLL patches.

## Key Files & Context
- `flake.nix`: The main entry point. Currently defines basic wrappers that ignore the more complex shell scripts.
- `patch_version.py`: Essential script to trick the ATAS installer into believing it's on Windows 11 and patches some required kernel APIs.

## Implementation Steps

### 1. Auto-Initialization Logic in `flake.nix`
- Define a shared shell script snippet (e.g., `wine-env`) within `flake.nix` that sets up the environment variables (`WINEPREFIX`, `WINEARCH`).
- Add `WINEDLLOVERRIDES="mscoree=d;mshtml=d"` to permanently disable Wine-Mono.
- Implement an automatic check inside this snippet: if the `.NET` runtime or `vcrun2022` is missing from the prefix, it automatically runs `wineboot -u` and `xvfb-run -a winetricks -q vcrun2022 dotnetdesktop7` to silently install them before continuing.
- Remove the separate `atas-setup` derivation, as setup becomes fully transparent.

### 2. Update `atas` and `atas-updater` wrappers
- Inject the `wine-env` auto-initialization logic into both the `atas` and `atas-updater` scripts.
- Provide a robust `--install` flag in the `atas` script that accepts an installer path and runs the installer with `/VERYSILENT`.
- Point the default execution path for `atas` to `OFT.PlatformX.exe` (the executable for ATAS X).
- Point `atas-updater` to `OFT.Platform.Updater.exe`.

### 3. Cleanup
- (Optional/Manual) Delete or document the deprecation of `atas.sh`, `atas-mono.sh`, and `install_atas.sh` as their logic will be fully integrated and streamlined into `flake.nix`.

## Verification
- Rebuild the flake development shell (`nix develop`).
- Run `atas-setup` to create a fresh, clean Wine prefix with .NET 7.
- Run `atas --install /path/to/ATAS_X.exe` to install the software.
- Run `atas` or `atas-updater` and verify that the application launches without complaining about missing .NET runtimes or crashing due to Mono conflicts.
