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
, xorg
, libkrb5
, webkitgtk_4_1
, imagemagick
, asar
, bash
, ripgrep
}:

let
  # VSCode最新版のメタデータを取得するスクリプト
  # Microsoft公式APIから最新のstableバージョン情報を取得
  inherit (stdenv.hostPlatform) system;
  plat = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    armv7l-linux = "linux-armhf";
  }.${system};

  # 最新版の情報（GitHub Actionsで自動更新される）
  version = "1.108.2";
  sha256 = "0p8v4q5c63jw0kk4wd6zl8n0071iljr6wjmbbvknbjrsmdxmm826";

  executableName = "code";
  longName = "Visual Studio Code";
  shortName = "Code";
  iconName = "vscode";
  libraryName = "vscode";

  systemdLibs = lib.getLib systemd;
in
stdenv.mkDerivation rec {
  pname = "vscode";
  inherit version;

  src = fetchurl {
    name = "vscode-${version}.tar.gz";
    url = "https://update.code.visualstudio.com/${version}/${plat}/stable";
    inherit sha256;
  };

  desktopItems = [
    (makeDesktopItem {
      name = executableName;
      desktopName = longName;
      comment = "Code Editing. Redefined.";
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
      keywords = [ "vscode" ];
      actions.new-empty-window = {
        name = "New Empty Window";
        exec = "${executableName} --new-window %F";
        icon = iconName;
      };
    })
    (makeDesktopItem {
      name = executableName + "-url-handler";
      desktopName = longName + " - URL Handler";
      comment = "Code Editing. Redefined.";
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
      keywords = [ "vscode" ];
      noDisplay = true;
    })
  ];

  nativeBuildInputs = [
    imagemagick
    autoPatchelfHook
    asar
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
    xorg.libxkbfile
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

  # Fix "Save as Root" functionality
  postPatch = ''
    packed="resources/app/node_modules.asar"
    unpacked="resources/app/node_modules"
    asar extract "$packed" "$unpacked"
    substituteInPlace $unpacked/@vscode/sudo-prompt/index.js \
      --replace-fail "/usr/bin/pkexec" "/run/wrappers/bin/pkexec" \
      --replace-fail "/bin/bash" "${bash}/bin/bash"
    rm -rf "$packed"
    ln -rs "$unpacked" "$packed"

    # Use nixpkgs ripgrep instead of bundled one
    chmod +x resources/app/node_modules/@vscode/ripgrep/bin/rg
    rm resources/app/node_modules/@vscode/ripgrep/bin/rg
    ln -s ${ripgrep}/bin/rg resources/app/node_modules/@vscode/ripgrep/bin/rg
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
    description = "Visual Studio Code - latest version";
    homepage = "https://code.visualstudio.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" "armv7l-linux" ];
    mainProgram = "code";
  };
}
