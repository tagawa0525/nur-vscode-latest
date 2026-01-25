# nur-vscode-latest

A NUR (Nix User Repository) that provides the latest versions of Visual Studio Code, automatically updated daily via GitHub Actions.

## Packages

| Package | Description |
|---------|-------------|
| `vscode` | Visual Studio Code (stable) - latest version |
| `vscode-insiders` | Visual Studio Code Insiders - latest preview version |

## Why This Repository?

The official nixpkgs VSCode packages may lag behind the latest releases. This repository:
- Automatically checks for new versions daily
- Updates SHA256 hashes using Microsoft's official API
- Verifies builds before committing changes
- Provides both stable and insiders editions

## Usage

### With Flakes

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur-vscode-latest.url = "github:tagawa0525/nur-vscode-latest";
  };

  outputs = { self, nixpkgs, nur-vscode-latest, ... }: {
    # Example: NixOS configuration
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            nur-vscode-latest.packages.${pkgs.system}.vscode
            # or for insiders:
            # nur-vscode-latest.packages.${pkgs.system}.vscode-insiders
          ];
        })
      ];
    };
  };
}
```

### With Home Manager (Flakes)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nur-vscode-latest.url = "github:tagawa0525/nur-vscode-latest";
  };

  outputs = { self, nixpkgs, home-manager, nur-vscode-latest, ... }: {
    homeConfigurations."user@host" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ({ pkgs, ... }: {
          home.packages = [
            nur-vscode-latest.packages.${pkgs.system}.vscode
          ];
        })
      ];
    };
  };
}
```

## Local Testing

```bash
# Build stable VSCode
nix build .#vscode

# Build VSCode Insiders
nix build .#vscode-insiders

# Run without installing
nix run .#vscode
```

## How It Works

GitHub Actions workflows run daily to:

1. Fetch the latest version metadata from Microsoft's official API
2. Compare with the current version in the repository
3. If a new version is available:
   - Update the version and SHA256 hash
   - Build the package to verify correctness
   - Commit and push the changes

### Schedule

| Package | Check Time (UTC) | Check Time (JST) |
|---------|------------------|------------------|
| VSCode (stable) | 22:30 | 07:30 |
| VSCode Insiders | 22:40 | 07:40 |

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`

## License

MIT
