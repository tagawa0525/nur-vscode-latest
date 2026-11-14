# nur-vscode-latest

A Nix flake that provides the latest versions of Visual Studio Code, automatically updated via GitHub Actions. It is a plain flake, not registered in [NUR](https://github.com/nix-community/NUR); use it as a flake input (see below).

## Packages

| Package           | Description                                          |
| ----------------- | ---------------------------------------------------- |
| `vscode`          | Visual Studio Code (stable) - latest version         |
| `vscode-insiders` | Visual Studio Code Insiders - latest preview version |

## Why This Repository?

The official nixpkgs VSCode packages may lag behind the latest releases. This repository:

- Automatically checks for new versions daily
- Updates SHA256 hashes using Microsoft's official API
- Verifies builds before committing changes
- Provides both stable and insiders editions

The packages are built with nixpkgs' `buildVscode`, so nixpkgs' fixes for VS Code's packaging apply here too. This repository only supplies the version and the per-architecture hashes (`pkgs/*/sources.json`), plus the libssl fix for the bundled Copilot runtime. See [ADR-0001](docs/adr/0001-build-vscode-with-nixpkgs-buildvscode.md).

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

### With the overlay

`overlays.default` replaces `vscode` and adds `vscode-insiders` (nixpkgs has none) in your `pkgs`, so modules that take `pkgs.vscode` (Home Manager's `programs.vscode`, for example) use these packages:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur-vscode-latest.url = "github:tagawa0525/nur-vscode-latest";
  };

  outputs = { nixpkgs, nur-vscode-latest, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ nur-vscode-latest.overlays.default ];
          nixpkgs.config.allowUnfree = true;
          # pkgs.vscode is now this repository's package
          environment.systemPackages = [ pkgs.vscode ];
        })
      ];
    };
  };
}
```

The overlay replaces the packages only on the supported platforms below, and leaves nixpkgs' `vscode` on other systems. It builds with your `pkgs` (not this flake's locked nixpkgs), so your nixpkgs needs `buildVscode` and handles the current VS Code layout (recent nixos-unstable). `default.nix` has the same requirement.

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
2. Compare with `sources.json` in the repository (version, build commit and hashes)
3. If anything differs (a new version, a new build of the same version, or a corrected hash):
   - Update the version, the build commit (the download URL is pinned by it) and the per-architecture SHA256 hashes
   - Build the package to verify correctness
   - Commit and push the changes

A weekly workflow also updates `flake.lock` (nixpkgs), and commits it only when `nix flake check` passes, so nixpkgs' fixes to `buildVscode` reach the packages. A failing update keeps the current lock.

### Schedule

| Package         | Check Time (UTC)                         | Check Time (JST)                         |
| --------------- | ---------------------------------------- | ---------------------------------------- |
| VSCode (stable) | 22:30                                    | 07:30                                    |
| VSCode Insiders | 03:00, 07:00, 11:00, 15:00, 19:00, 23:00 | 12:00, 16:00, 20:00, 00:00, 04:00, 08:00 |

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`

## License

The Nix expressions in this repository are MIT licensed. The packages install Microsoft's proprietary VS Code binaries, which are unfree (`meta.license = lib.licenses.unfree`). `packages.<system>` is built with this flake's nixpkgs, which already sets `config.allowUnfree = true`. The overlay and `default.nix` build with your `pkgs`, so you need `config.allowUnfree = true` (or an equivalent `allowUnfreePredicate`) there. The MIT license does not cover those binaries.
