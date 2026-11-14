{
  description = "Latest VS Code versions for Nix, auto-updated via GitHub Actions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      editions = [
        "vscode"
        "vscode-insiders"
      ];
    in
    {
      # nixpkgs の vscode と vscode-insiders を、このリポジトリのものに置き換える
      # 対応しないシステムでは nixpkgs のものを残す（置き換えると評価で Unsupported system になる）。条件は prev で見る
      # （final で見ると、この overlay の属性の名前を決めるのに final が要り、無限に再帰する）
      overlays.default =
        final: prev:
        nixpkgs.lib.optionalAttrs (builtins.elem prev.stdenv.hostPlatform.system systems) (
          import ./default.nix { pkgs = final; }
        );

      packages = forAllSystems (system: import ./default.nix { pkgs = pkgsFor system; });

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (pkgs) lib;

          # 同じ src のハッシュを全アーキテクチャで再利用すると、x64 以外の tarball でハッシュが合わない（#11）
          srcHashesPerSystem =
            name:
            let
              hashes = map (s: self.packages.${s}.${name}.src.outputHash) systems;
            in
            pkgs.runCommand "${name}-src-hash-per-system" { } (
              if lib.length (lib.unique hashes) == lib.length hashes then
                "touch $out"
              else
                ''
                  echo "${name} のアーキテクチャごとの src のハッシュが同じ: ${toString hashes}" >&2
                  exit 1
                ''
            );

          # 「Save as Root」が NixOS の pkexec（setuid の wrapper）を呼ぶこと（#12）
          saveAsRootUsesWrapper =
            name: pkg:
            pkgs.runCommand "${name}-save-as-root-uses-wrapper" { } ''
              f=$(echo ${pkg}/lib/*/resources/app/node_modules/@vscode/sudo-prompt/index.js)
              if [ ! -f "$f" ]; then
                echo "sudo-prompt の index.js が展開されていない" >&2
                exit 1
              fi
              grep -q /run/wrappers/bin/pkexec "$f"
              # `! grep` は set -e で止まらないので if で落とす
              if grep -q /usr/bin/pkexec "$f"; then
                echo "/usr/bin/pkexec が残っている" >&2
                exit 1
              fi
              touch $out
            '';

          # 同梱の Copilot の SDK の runtime.node が dlopen する libssl を見つけられること（#10）
          copilotRuntimeFindsOpenssl =
            name: pkg:
            pkgs.runCommand "${name}-copilot-runtime-finds-openssl" { nativeBuildInputs = [ pkgs.patchelf ]; }
              ''
                found=0
                for f in $(find -L ${pkg}/lib -path '*/@github/copilot-sdk-linux-*/prebuilds/*/runtime.node'); do
                  patchelf --print-rpath "$f" | tr : '\n' | grep -qx '${lib.getLib pkgs.openssl}/lib'
                  found=$((found + 1))
                done
                [ "$found" -gt 0 ]
                touch $out
              '';

          # overlay を当てた nixpkgs の vscode が、このリポジトリの版になること
          overlayReplacesNixpkgs =
            name:
            let
              overlaid = import nixpkgs {
                inherit system;
                config.allowUnfree = true;
                overlays = [ self.overlays.default ];
              };
            in
            # version だけで比べると、nixpkgs が同じ版に追いついたときに overlay が効かなくても通る
            pkgs.runCommand "${name}-overlay-replaces-nixpkgs" { } (
              if overlaid.${name}.drvPath == self.packages.${system}.${name}.drvPath then
                "touch $out"
              else
                ''
                  echo "overlay の ${name} は ${overlaid.${name}.version}（このリポジトリは ${
                    self.packages.${system}.${name}.version
                  }）" >&2
                  exit 1
                ''
            );

          # 対応しないシステム（aarch64-darwin）では、overlay が nixpkgs の vscode を残すこと
          overlayKeepsUnsupportedSystems =
            let
              darwin = "aarch64-darwin";
              plain = import nixpkgs {
                system = darwin;
                config.allowUnfree = true;
              };
              overlaid = import nixpkgs {
                system = darwin;
                config.allowUnfree = true;
                overlays = [ self.overlays.default ];
              };
              kept = builtins.tryEval (overlaid.vscode.drvPath == plain.vscode.drvPath);
            in
            pkgs.runCommand "overlay-keeps-unsupported-systems" { } (
              if kept.success && kept.value then
                "touch $out"
              else
                ''
                  echo "overlay が ${darwin} の vscode を置き換えた（評価が通らないか、nixpkgs のものと違う）" >&2
                  exit 1
                ''
            );
        in
        {
          overlay-keeps-unsupported-systems = overlayKeepsUnsupportedSystems;
        }
        // lib.listToAttrs (
          lib.concatMap (
            name:
            let
              pkg = self.packages.${system}.${name};
            in
            [
              (lib.nameValuePair "${name}-src-hash-per-system" (srcHashesPerSystem name))
              (lib.nameValuePair "${name}-save-as-root-uses-wrapper" (saveAsRootUsesWrapper name pkg))
              (lib.nameValuePair "${name}-copilot-runtime-finds-openssl" (copilotRuntimeFindsOpenssl name pkg))
              (lib.nameValuePair "${name}-overlay-replaces-nixpkgs" (overlayReplacesNixpkgs name))
            ]
          ) editions
        )
      );
    };
}
