{ lib
, stdenv
, fetchurl
, autoPatchelfHook
}:

stdenv.mkDerivation rec {
  pname = "opencode";
  version = "1.1.25";

  # プラットフォーム固有のバイナリパッケージを使用
  src = fetchurl {
    url = "https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-${version}.tgz";
    hash = "sha256-/cPLh7nn8TLs3/FX33Vl25+IskU7X3JPArGibbAsP34=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  dontBuild = true;
  dontStrip = true;  # バイナリを縮小しない

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp bin/opencode $out/bin/opencode
    chmod +x $out/bin/opencode

    runHook postInstall
  '';

  meta = with lib; {
    description = "Open Code - AI pair programmer CLI";
    homepage = "https://opencode.ai";
    license = licenses.unfree;
    mainProgram = "opencode";
    platforms = [ "x86_64-linux" ];
  };
}
