# nixpkgs の buildVscode に、sources.json の版、ビルドの commit、アーキテクチャごとのハッシュを渡す（ADR-0001）
{
  lib,
  stdenv,
  buildVscode,
  fetchurl,
  openssl,
}:

{
  isInsiders,
  sources,
}:

# commit が壊れていれば（手での編集、API の応答の変化）、commit:null のような URL を取りに行く前に止める
assert lib.assertMsg (
  builtins.match "[0-9a-f]{40}" sources.commit != null
) "sources.json の commit が 40 桁の 16 進数でない: ${sources.commit}";

let
  inherit (stdenv.hostPlatform) system;
  inherit (sources) version;

  plat =
    {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
    }
    .${system} or (throw "Unsupported system: ${system}");

  suffix = lib.optionalString isInsiders "-insiders";
  executableName = "code" + suffix;
  channel = if isInsiders then "insider" else "stable";

  vscode = buildVscode {
    pname = "vscode" + suffix;
    inherit version executableName;
    longName = "Visual Studio Code" + lib.optionalString isInsiders " - Insiders";
    shortName = "Code" + lib.optionalString isInsiders " - Insiders";
    sourceExecutableName = executableName;
    commandLineArgs = "";

    src = fetchurl {
      name = "VSCode_${version}_${plat}.tar.gz";
      # latest や版の URL にしない。同じ版のまま中身が差し替わると、固定した hash と合わなくなる（ADR-0001 の「変更」）
      url = "https://update.code.visualstudio.com/commit:${sources.commit}/${plat}/${channel}";
      hash = sources.hashes.${system};
    };
    sourceRoot = "";

    hasVsceSign = true;
    # 版の更新は GitHub Actions のワークフローが sources.json を書き換える
    updateScript = null;
    tests = { };

    meta = {
      description =
        if isInsiders then
          "Visual Studio Code Insiders - latest preview version"
        else
          "Visual Studio Code - latest version";
      homepage =
        if isInsiders then "https://code.visualstudio.com/insiders/" else "https://code.visualstudio.com/";
      license = lib.licenses.unfree;
      platforms = lib.attrNames sources.hashes;
      mainProgram = executableName;
    };
  };
in
vscode.overrideAttrs (old: {
  # 同梱の Copilot の SDK の runtime.node は、libssl.so.3 を（NEEDED でなく）実行中に dlopen する。dlopen は呼び出し元の
  # RUNPATH を探すので、runtime.node の RUNPATH にだけ足す（比べた方式は #10。vsce-sign は generic.nix が NEEDED に足す）。
  # postFixup の文字列は autoPatchelf より先に走り、autoPatchelf が RUNPATH を上書きするので、postFixupHooks に足して
  # 後に実行する。x86_64 と aarch64 で見つからなければ、上流で置き場が変わったので止める（毎日の自動更新で黙って元に戻さない）
  preFixup = (old.preFixup or "") + ''
    addOpensslRunpath() {
      local nodes=0 f
      for f in "$out"/lib/vscode/resources/app/node_modules/@github/copilot-sdk-linux-*/prebuilds/*/runtime.node; do
        [ -e "$f" ] || continue
        patchelf --add-rpath ${lib.getLib openssl}/lib "$f"
        nodes=$((nodes + 1))
      done
      ${lib.optionalString (stdenv.hostPlatform.isx86_64 || stdenv.hostPlatform.isAarch64) ''
        if [ "$nodes" -eq 0 ]; then
          echo "libssl を dlopen する Copilot の runtime.node が見つからない（置き場が変わった）" >&2
          exit 1
        fi
      ''}
    }
    postFixupHooks+=(addOpensslRunpath)
  '';
})
