{
  description = "ATAS X - GE-Proton11-1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

        patch-wbemprox = pkgs.writeText "patch-wbemprox.py" ''
import sys
d = open(sys.argv[1],"rb").read()
for o,n in [("Serial number","ATAS-SN-2026X"),("deaddead-dead-dead-dead-deaddeaddead","6F88E200-A973-11EE-8C90-0800200C9A66"),("None","ATAS"),("WINEHDISK","DISK-ATAS"),("Base Board","ATAS-MB-X1"),("VideoController1","NVidiaGeForceRTX"),("VideoProcessor","GeForceRTX4050")]:
    ob=o.encode("utf-16-le"); nb=n.encode("utf-16-le")
    assert len(ob)==len(nb)
    c=d.count(ob)
    if c: d=d.replace(ob,nb); print(f"OK: {o!r} ({c}x)")
    else: print(f"SKIP: {o!r} not found")
open(sys.argv[1],"wb").write(d)
'';

        ge-proton-src = pkgs.fetchurl {
          url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-1/GE-Proton11-1.tar.gz";
          hash = "sha256-zm3WY+oBcloxgF7VwWVyOiU83wlFpmQpBzMHQq4t5eQ=";
        };

        ge-proton = pkgs.stdenv.mkDerivation {
          name = "ge-proton-11-1";
          src = ge-proton-src;
          sourceRoot = "GE-Proton11-1/files";
          nativeBuildInputs = [ pkgs.python3 ];
          installPhase = "mkdir -p $out && cp -r * $out/";
          fixupPhase = ''
for dll in "$out/lib/wine/x86_64-windows/wbemprox.dll" "$out/lib/wine/i386-windows/wbemprox.dll"; do
  [ -f "$dll" ] && python3 ${patch-wbemprox} "$dll"
done
'';
        };

        wine-bin = pkgs.runCommand "wine-wrapper" {
          nativeBuildInputs = [ pkgs.makeWrapper ];
          gp = ge-proton;
        } ''
          cp -r $gp $out
          chmod -R u+w $out
          for f in $(find $out -type f); do
            if file -b "$f" 2>/dev/null | grep -q "ELF 64-bit"; then
              patchelf --set-interpreter "${pkgs.stdenv.cc.bintools.dynamicLinker}" "$f" 2>/dev/null || true
            elif file -b "$f" 2>/dev/null | grep -q "ELF 32-bit"; then
              patchelf --set-interpreter "${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2" "$f" 2>/dev/null || true
            fi
          done
        '';

        window-hider-hook = pkgs.pkgsCross.mingwW64.stdenv.mkDerivation {
          name = "window-hider-hook";
          src = ./.;
          dontUnpack = true;
          buildPhase = ''
            $CXX -shared -static -s -o window_hider_hook.dll ${./window_hider_hook.cpp} -luser32
          '';
          installPhase = ''
            mkdir -p $out/lib
            cp window_hider_hook.dll $out/lib/
          '';
        };

        atas-launcher = pkgs.pkgsCross.mingwW64.stdenv.mkDerivation {
          name = "atas-launcher";
          src = ./.;
          dontUnpack = true;
          buildPhase = ''
            $CXX -static -s -o atas_launcher.exe ${./atas_launcher.cpp}
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp atas_launcher.exe $out/bin/
          '';
        };

        atas-sh-content = builtins.replaceStrings [
          "@wineBin@"
          "@winetricks@"
          "@nss@"
          "@gnutls@"
          "@vulkanLoader@"
          "@libGL@"
          "@freetype@"
          "@fontconfig@"
          "@libpng@"
          "@zlib@"
          "@bzip2@"
          "@brotli@"
          "@expat@"
          "@wayland@"
          "@libdecor@"
          "@libxkbcommon@"
          "@libX11@"
          "@libXext@"
          "@pkgsi686Freetype@"
          "@pkgsi686Fontconfig@"
          "@pkgsi686Libpng@"
          "@pkgsi686Zlib@"
          "@pkgsi686Bzip2@"
          "@pkgsi686Brotli@"
          "@pkgsi686Expat@"
          "@pkgsi686Wayland@"
          "@pkgsi686Libdecor@"
          "@pkgsi686Libxkbcommon@"
          "@pkgsi686Libx11@"
          "@pkgsi686Libxext@"
          "@libpulse@"
          "@alsaLib@"
          "@pkgsi686Libpulse@"
          "@pkgsi686AlsaLib@"
          "@udev@"
          "@pkgsi686Udev@"
          "@cacert@"
          "@windowHiderHook@"
          "@atasLauncher@"
        ] [
          "${wine-bin}"
          "${pkgs.winetricks}"
          "${pkgs.nss.out}"
          "${pkgs.gnutls.out}"
          "${pkgs.vulkan-loader}"
          "${pkgs.libGL}"
          "${pkgs.freetype}"
          "${pkgs.fontconfig.lib}"
          "${pkgs.libpng}"
          "${pkgs.zlib}"
          "${pkgs.bzip2.out}"
          "${pkgs.brotli.lib}"
          "${pkgs.expat}"
          "${pkgs.wayland}"
          "${pkgs.libdecor}"
          "${pkgs.libxkbcommon}"
          "${pkgs.xorg.libX11}"
          "${pkgs.xorg.libXext}"
          "${pkgs.pkgsi686Linux.freetype}"
          "${pkgs.pkgsi686Linux.fontconfig.lib}"
          "${pkgs.pkgsi686Linux.libpng}"
          "${pkgs.pkgsi686Linux.zlib}"
          "${pkgs.pkgsi686Linux.bzip2.out}"
          "${pkgs.pkgsi686Linux.brotli.lib}"
          "${pkgs.pkgsi686Linux.expat}"
          "${pkgs.pkgsi686Linux.wayland}"
          "${pkgs.pkgsi686Linux.libdecor}"
          "${pkgs.pkgsi686Linux.libxkbcommon}"
          "${pkgs.pkgsi686Linux.libx11}"
          "${pkgs.pkgsi686Linux.libxext}"
          "${pkgs.libpulseaudio}"
          "${pkgs.alsa-lib}"
          "${pkgs.pkgsi686Linux.libpulseaudio}"
          "${pkgs.pkgsi686Linux.alsa-lib}"
          "${pkgs.udev}"
          "${pkgs.pkgsi686Linux.udev}"
          "${pkgs.cacert.unbundled}"
          "${window-hider-hook}"
          "${atas-launcher}"
        ] (builtins.readFile ./atas.sh);
        atas = pkgs.writeShellScriptBin "atas" atas-sh-content;

        atas-updater-sh-content = builtins.replaceStrings [
          "@wineBin@"
          "@winetricks@"
          "@nss@"
          "@gnutls@"
          "@vulkanLoader@"
          "@libGL@"
          "@freetype@"
          "@fontconfig@"
          "@libpng@"
          "@zlib@"
          "@bzip2@"
          "@brotli@"
          "@expat@"
          "@wayland@"
          "@libdecor@"
          "@libxkbcommon@"
          "@libX11@"
          "@libXext@"
          "@pkgsi686Freetype@"
          "@pkgsi686Fontconfig@"
          "@pkgsi686Libpng@"
          "@pkgsi686Zlib@"
          "@pkgsi686Bzip2@"
          "@pkgsi686Brotli@"
          "@pkgsi686Expat@"
          "@pkgsi686Wayland@"
          "@pkgsi686Libdecor@"
          "@pkgsi686Libxkbcommon@"
          "@pkgsi686Libx11@"
          "@pkgsi686Libxext@"
          "@libpulse@"
          "@alsaLib@"
          "@pkgsi686Libpulse@"
          "@pkgsi686AlsaLib@"
          "@udev@"
          "@pkgsi686Udev@"
          "@cacert@"
        ] [
          "${wine-bin}"
          "${pkgs.winetricks}"
          "${pkgs.nss.out}"
          "${pkgs.gnutls.out}"
          "${pkgs.vulkan-loader}"
          "${pkgs.libGL}"
          "${pkgs.freetype}"
          "${pkgs.fontconfig.lib}"
          "${pkgs.libpng}"
          "${pkgs.zlib}"
          "${pkgs.bzip2.out}"
          "${pkgs.brotli.lib}"
          "${pkgs.expat}"
          "${pkgs.wayland}"
          "${pkgs.libdecor}"
          "${pkgs.libxkbcommon}"
          "${pkgs.xorg.libX11}"
          "${pkgs.xorg.libXext}"
          "${pkgs.pkgsi686Linux.freetype}"
          "${pkgs.pkgsi686Linux.fontconfig.lib}"
          "${pkgs.pkgsi686Linux.libpng}"
          "${pkgs.pkgsi686Linux.zlib}"
          "${pkgs.pkgsi686Linux.bzip2.out}"
          "${pkgs.pkgsi686Linux.brotli.lib}"
          "${pkgs.pkgsi686Linux.expat}"
          "${pkgs.pkgsi686Linux.wayland}"
          "${pkgs.pkgsi686Linux.libdecor}"
          "${pkgs.pkgsi686Linux.libxkbcommon}"
          "${pkgs.pkgsi686Linux.libx11}"
          "${pkgs.pkgsi686Linux.libxext}"
          "${pkgs.libpulseaudio}"
          "${pkgs.alsa-lib}"
          "${pkgs.pkgsi686Linux.libpulseaudio}"
          "${pkgs.pkgsi686Linux.alsa-lib}"
          "${pkgs.udev}"
          "${pkgs.pkgsi686Linux.udev}"
          "${pkgs.cacert.unbundled}"
        ] (builtins.readFile ./atas-updater.sh);
        atas-updater = pkgs.writeShellScriptBin "atas-updater" atas-updater-sh-content;

      in {
        packages = { default = wine-bin; inherit wine-bin atas atas-updater ge-proton window-hider-hook atas-launcher; };
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ wine-bin winetricks python3 atas atas-updater gamescope cage ];
          shellHook = ''
export WINEPREFIX="''${WINEPREFIX:-$HOME/.local/share/wineprefixes/atas}"
export WINEARCH=win64
export DISPLAY="''${DISPLAY:-:0}"
export WINE_WAYLAND_DISPLAY="''${WINE_WAYLAND_DISPLAY:-''${WAYLAND_DISPLAY}}"
export XAUTHORITY="''${XAUTHORITY}"
'';
        };
      });
}
