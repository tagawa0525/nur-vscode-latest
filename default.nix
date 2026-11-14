# nur-vscode-latest
# Latest VS Code versions for Nix, auto-updated via GitHub Actions
{
  pkgs ? import <nixpkgs> { },
}:

{
  vscode = pkgs.callPackage ./pkgs/vscode { };
  vscode-insiders = pkgs.callPackage ./pkgs/vscode-insiders { };
}
