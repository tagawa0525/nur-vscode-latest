{ lib
, stdenv
, fetchurl
, autoPatchelfHook
}:

let
  # プラットフォームごとの設定
  platforms = {
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-P+l5IVSJ3BsxRj+t+V7S0tVHOplpRHu3pGQx9FeIR9Q=";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      hash = "sha256-4hSx07Wv1M0t6Rdzkwx0GqPrkMseNmX+l+3FkvWqEy8=";
    };
  };

  platformInfo = platforms.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "claude-code";
  version = "2.1.12";

  # Google Cloud Storageからネイティブバイナリを取得
  src = fetchurl {
    url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${platformInfo.platform}/claude";
    hash = platformInfo.hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;  # バイナリを縮小しない

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src $out/bin/claude
    chmod +x $out/bin/claude

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code - AI pair programmer CLI (native binary)";
    homepage = "https://claude.ai/claude-code";
    license = licenses.unfree;
    mainProgram = "claude";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
