{ lib
, stdenv
, fetchurl
, makeWrapper
, nodejs
}:

stdenv.mkDerivation rec {
  pname = "claude-code";
  version = "2.1.12";

  src = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-ltKE++NvgGBrT9XfliKXyc+NeewdmnSqjRbfk7t/BoU=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/claude-code $out/bin
    cp -r * $out/lib/claude-code/

    # claudeコマンドのラッパーを作成
    makeWrapper ${nodejs}/bin/node $out/bin/claude \
      --add-flags "$out/lib/claude-code/cli.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code - AI pair programmer CLI";
    homepage = "https://claude.ai/claude-code";
    license = licenses.unfree;
    mainProgram = "claude";
    platforms = platforms.all;
  };
}
