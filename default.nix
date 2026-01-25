# nur-vscode-latest
# NUR providing latest VSCode versions with daily auto-updates
{ pkgs ? import <nixpkgs> { } }:

{
  vscode = pkgs.callPackage ./pkgs/vscode { };
  vscode-insiders = pkgs.callPackage ./pkgs/vscode-insiders { };
}
