{ callPackage, lib }:

callPackage ../build-vscode-latest.nix { } {
  isInsiders = true;
  sources = lib.importJSON ./sources.json;
}
