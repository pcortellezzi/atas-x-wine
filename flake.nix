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

        atas-sh = pkgs.substituteAll {
          src = ./atas.sh;
          wineBin = "${wine-bin}";
          winetricks = "${pkgs.winetricks}";
          nss = "${pkgs.nss.out}";
          gnutls = "${pkgs.gnutls.out}";
          vulkanLoader = "${pkgs.vulkan-loader}";
          libGL = "${pkgs.libGL}";
          freetype = "${pkgs.freetype}";
          fontconfig = "${pkgs.fontconfig.lib}";
          libpng = "${pkgs.libpng}";
          zlib = "${pkgs.zlib}";
          bzip2 = "${pkgs.bzip2.out}";
          brotli = "${pkgs.brotli.lib}";
          expat = "${pkgs.expat}";
          wayland = "${pkgs.wayland}";
          libdecor = "${pkgs.libdecor}";
          libxkbcommon = "${pkgs.libxkbcommon}";
          libX11 = "${pkgs.xorg.libX11}";
          libXext = "${pkgs.xorg.libXext}";
          pkgsi686Freetype = "${pkgs.pkgsi686Linux.freetype}";
          pkgsi686Fontconfig = "${pkgs.pkgsi686Linux.fontconfig.lib}";
          pkgsi686Libpng = "${pkgs.pkgsi686Linux.libpng}";
          pkgsi686Zlib = "${pkgs.pkgsi686Linux.zlib}";
          pkgsi686Bzip2 = "${pkgs.pkgsi686Linux.bzip2.out}";
          pkgsi686Brotli = "${pkgs.pkgsi686Linux.brotli.lib}";
          pkgsi686Expat = "${pkgs.pkgsi686Linux.expat}";
          pkgsi686Wayland = "${pkgs.pkgsi686Linux.wayland}";
          pkgsi686Libdecor = "${pkgs.pkgsi686Linux.libdecor}";
          pkgsi686Libxkbcommon = "${pkgs.pkgsi686Linux.libxkbcommon}";
          pkgsi686Libx11 = "${pkgs.pkgsi686Linux.libx11}";
          pkgsi686Libxext = "${pkgs.pkgsi686Linux.libxext}";
          cacert = "${pkgs.cacert.unbundled}";
          windowHiderHook = "${window-hider-hook}";
          atasLauncher = "${atas-launcher}";
        };
        atas = pkgs.writeShellScriptBin "atas" (builtins.readFile atas-sh);;

        atas-updater-sh = pkgs.substituteAll {
          src = ./atas-updater.sh;
          wineBin = "${wine-bin}";
          winetricks = "${pkgs.winetricks}";
          nss = "${pkgs.nss.out}";
          gnutls = "${pkgs.gnutls.out}";
          vulkanLoader = "${pkgs.vulkan-loader}";
          libGL = "${pkgs.libGL}";
          freetype = "${pkgs.freetype}";
          fontconfig = "${pkgs.fontconfig.lib}";
          libpng = "${pkgs.libpng}";
          zlib = "${pkgs.zlib}";
          bzip2 = "${pkgs.bzip2.out}";
          brotli = "${pkgs.brotli.lib}";
          expat = "${pkgs.expat}";
          wayland = "${pkgs.wayland}";
          libdecor = "${pkgs.libdecor}";
          libxkbcommon = "${pkgs.libxkbcommon}";
          libX11 = "${pkgs.xorg.libX11}";
          libXext = "${pkgs.xorg.libXext}";
          pkgsi686Freetype = "${pkgs.pkgsi686Linux.freetype}";
          pkgsi686Fontconfig = "${pkgs.pkgsi686Linux.fontconfig.lib}";
          pkgsi686Libpng = "${pkgs.pkgsi686Linux.libpng}";
          pkgsi686Zlib = "${pkgs.pkgsi686Linux.zlib}";
          pkgsi686Bzip2 = "${pkgs.pkgsi686Linux.bzip2.out}";
          pkgsi686Brotli = "${pkgs.pkgsi686Linux.brotli.lib}";
          pkgsi686Expat = "${pkgs.pkgsi686Linux.expat}";
          pkgsi686Wayland = "${pkgs.pkgsi686Linux.wayland}";
          pkgsi686Libdecor = "${pkgs.pkgsi686Linux.libdecor}";
          pkgsi686Libxkbcommon = "${pkgs.pkgsi686Linux.libxkbcommon}";
          pkgsi686Libx11 = "${pkgs.pkgsi686Linux.libx11}";
          pkgsi686Libxext = "${pkgs.pkgsi686Linux.libxext}";
          cacert = "${pkgs.cacert.unbundled}";
        };
        atas-updater = pkgs.writeShellScriptBin "atas-updater" (builtins.readFile atas-updater-sh);;

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
