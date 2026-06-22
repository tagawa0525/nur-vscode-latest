{ lib
, stdenv
, fetchurl
, coreutils
, gnugrep
, copyDesktopItems
, makeDesktopItem
, autoPatchelfHook
, buildPackages
, alsa-lib
, at-spi2-atk
, fontconfig
, glib
, libdbusmenu
, libsecret
, libXScrnSaver
, libxshmfence
, libglvnd
, nspr
, nss
, systemd
, wayland
, libxkbfile
, libkrb5
, webkitgtk_4_1
, imagemagick
, bash
, ripgrep
, libXtst
, libjpeg8
, pipewire
, libei
}:

let
  # Platform-specific configuration for VSCode Insiders
  # Version info is fetched from Microsoft's official API
  inherit (stdenv.hostPlatform) system;
  plat = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    armv7l-linux = "linux-armhf";
  }.${system};

  # Latest version info (auto-updated by GitHub Actions)
  version = "1.126.0-insider";
  sha256 = "1jzwp92cx9fvpi1vzrf2jmqjxk6jaaamn5y41faxc56n80d1mj77";

  executableName = "code-insiders";
  longName = "Visual Studio Code - Insiders";
  shortName = "Code - Insiders";
  iconName = "vscode-insiders";
  libraryName = "vscode-insiders";

  systemdLibs = lib.getLib systemd;
in
stdenv.mkDerivation rec {
  pname = "vscode-insiders";
  inherit version;

  src = fetchurl {
    name = "vscode-insiders-${version}.tar.gz";
    url = "https://update.code.visualstudio.com/latest/${plat}/insider";
    inherit sha256;
  };

  desktopItems = [
    (makeDesktopItem {
      name = executableName;
      desktopName = longName;
      comment = "Code Editing. Redefined. (Insiders Build)";
      genericName = "Text Editor";
      exec = "${executableName} %F";
      icon = iconName;
      startupNotify = true;
      startupWMClass = shortName;
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      keywords = [ "vscode" "insiders" ];
      actions.new-empty-window = {
        name = "New Empty Window";
        exec = "${executableName} --new-window %F";
        icon = iconName;
      };
    })
    (makeDesktopItem {
      name = executableName + "-url-handler";
      desktopName = longName + " - URL Handler";
      comment = "Code Editing. Redefined. (Insiders Build)";
      genericName = "Text Editor";
      exec = executableName + " --open-url %U";
      icon = iconName;
      startupNotify = true;
      startupWMClass = shortName;
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      mimeTypes = [ "x-scheme-handler/${iconName}" ];
      keywords = [ "vscode" "insiders" ];
      noDisplay = true;
    })
  ];

  nativeBuildInputs = [
    imagemagick
    autoPatchelfHook
    copyDesktopItems
    # override doesn't preserve splicing https://github.com/NixOS/nixpkgs/issues/132651
    (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
  ];

  buildInputs = [
    libsecret
    libXScrnSaver
    libxshmfence
    alsa-lib
    at-spi2-atk
    libkrb5
    nss
    nspr
    systemdLibs
    webkitgtk_4_1
    libxkbfile
    # GitHub Copilot computer-use prebuild (computer.node) native deps
    libXtst
    libjpeg8
    (lib.getLib pipewire) # only libpipewire-0.3.so.0 is needed, not the daemons
    libei
  ];

  runtimeDependencies = [
    systemdLibs
    fontconfig.lib
    libdbusmenu
    wayland
    libsecret
  ];

  dontBuild = true;
  dontConfigure = true;

  # VSCode 1.122+ unpacks most of node_modules at source level; node_modules.asar
  # only contains vsda (signature library) and must be left alone for it to load.
  postPatch = ''
    # Fix "Save as Root" functionality (sudo-prompt pkexec/bash paths)
    substituteInPlace resources/app/node_modules/@vscode/sudo-prompt/index.js \
      --replace-fail "/usr/bin/pkexec" "/run/wrappers/bin/pkexec" \
      --replace-fail "/bin/bash" "${bash}/bin/bash"

    # Use nixpkgs ripgrep instead of the bundled one. 1.122+ renamed the package
    # to ripgrep-universal and moved the binary under an arch-specific subdir.
    rgPath="resources/app/node_modules/@vscode/ripgrep-universal/bin/${plat}/rg"
    rm "$rgPath"
    ln -s ${ripgrep}/bin/rg "$rgPath"

    # Drop the musl-libc Copilot agent (used by Alpine/musl distros).
    # It cannot be autoPatchelf'd against glibc and is never loaded on NixOS.
    rm -rf resources/app/node_modules/@github/copilot-linuxmusl-x64
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/${libraryName}" "$out/bin"
    cp -r ./* "$out/lib/${libraryName}"
    ln -s "$out/lib/${libraryName}/bin/${executableName}" "$out/bin/${executableName}"

    # Install icons
    mkdir -p "$out/share/pixmaps"
    icon_file="$out/lib/${libraryName}/resources/app/resources/linux/code.png"
    cp "$icon_file" "$out/share/pixmaps/${iconName}.png"

    # Dynamically determine size of icon and place in appropriate directory
    size=$(identify -format "%wx%h" "$icon_file")
    mkdir -p "$out/share/icons/hicolor/$size/apps"
    cp "$icon_file" "$out/share/icons/hicolor/$size/apps/${iconName}.png"

    # Override the previously determined VSCODE_PATH with the one we know to be correct
    sed -i "/ELECTRON=/iVSCODE_PATH='$out/lib/${libraryName}'" "$out/bin/${executableName}"
    grep -q "VSCODE_PATH='$out/lib/${libraryName}'" "$out/bin/${executableName}" # check if sed succeeded

    # Remove native encryption code
    rm -rf $out/lib/${libraryName}/resources/app/node_modules/vscode-encrypt

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libdbusmenu ]}
      --prefix PATH : ${lib.makeBinPath [ glib gnugrep coreutils ]}
      --set-default ELECTRON_OZONE_PLATFORM_HINT "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+auto}}"
    )
  '';

  postFixup = ''
    patchelf \
      --add-needed ${libglvnd}/lib/libGLESv2.so.2 \
      --add-needed ${libglvnd}/lib/libGL.so.1 \
      --add-needed ${libglvnd}/lib/libEGL.so.1 \
      $out/lib/${libraryName}/${executableName}
  '';

  meta = with lib; {
    description = "Visual Studio Code Insiders - latest preview version";
    homepage = "https://code.visualstudio.com/insiders/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" "armv7l-linux" ];
    mainProgram = "code-insiders";
  };
}
