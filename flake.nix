{
  description = "Trener Językowy — Flutter + CEF (WebGL) dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      cefBuildInputs = with pkgs; [
        flutter
        cmake
        ninja
        clang
        pkg-config
        gtk3
        glib
        pango
        cairo
        gdk-pixbuf
        atk
        at-spi2-atk
        at-spi2-core
        harfbuzz
        zlib
        libepoxy
        nss
        nspr
        cups
        libgbm
        mesa
        libGL
        libdrm
        expat
        alsa-lib
        dbus
        libxkbcommon
        freetype
        fontconfig
        libffi
        xorg.libX11
        xorg.libXcomposite
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXrandr
        xorg.libXrender
        xorg.libXtst
        xorg.libxcb
        xorg.libxshmfence
        xorg.libXi
        # linker helpers used by webview_cef on NixOS
        sysprof
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
      ];
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        name = "trener-jezykowy";
        packages = cefBuildInputs;
        shellHook = ''
          echo "Trener Językowy — nix develop"
          echo "  flutter pub get && flutter build linux --release"
          export CHROME_EXECUTABLE="${pkgs.chromium}/bin/chromium"
        '';
      };
    };
}
