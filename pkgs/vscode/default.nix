{ callPackage, lib }:

callPackage ../build-vscode-latest.nix { } {
  isInsiders = false;
  sources = lib.importJSON ./sources.json;
}
