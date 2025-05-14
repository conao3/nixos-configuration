# NixOS and nix-darwin Configuration

This repository contains my personal configuration for both NixOS and macOS (via nix-darwin).

## Structure

- `flake.nix` - The main entry point for the configuration
- `darwin/` - macOS-specific configuration
- `nixos/` - NixOS-specific configuration
- `hosts/` - Host-specific configuration
- `home-manager/` - User-environment configuration
  - `home.nix` - Main home-manager configuration file
  - `modules/` - Modularized home-manager configurations
    - `common.nix` - Common home-manager settings
    - `packages.nix` - Package management
    - `programs.nix` - Program configurations
  - `programs/` - Program-specific configurations
  - `ext/` - External configurations and resources
  - `pkgs/` - Custom package definitions
- `lib/` - Shared library functions and modules
  - `home-manager-common.nix` - Common home-manager config for both NixOS and Darwin
  - `nix-common.nix` - Common Nix settings for both systems

## Usage

### On NixOS

```bash
# Switch to the NixOS configuration
sudo nixos-rebuild switch --flake .#helios
```

### On macOS

```bash
# Switch to the Darwin configuration
nix run nix-darwin -- switch --flake .#macos

# If you need to allow unfree packages
NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin --impure -- switch --flake .#macos
```

## Adding a New Host

1. Create a new directory under `hosts/` with the hostname
2. Create a `default.nix` file in that directory
3. Add the configuration to `flake.nix`

## Adding New Programs

1. Add the program to `home-manager/modules/programs.nix`
2. If needed, create a configuration file in `home-manager/programs/`

## Adding New Packages

Add the package to the appropriate list in `home-manager/modules/packages.nix`
