# nixos-configuration

Personal Nix configuration for NixOS and macOS systems using Nix flakes, nix-darwin, and home-manager.

## Overview

This repository contains declarative system configurations for:

- **NixOS** - Full system configuration for Linux machines
- **macOS** - System configuration via nix-darwin
- **home-manager** - User environment and dotfiles management

## Repository Structure

```
.
├── flake.nix          # Main flake entry point
├── darwin/            # macOS (nix-darwin) configuration
├── nixos/             # NixOS-specific modules
├── hosts/             # Machine-specific configurations
│   ├── helios/        # NixOS workstation
│   └── eos/           # NixOS machine
├── home-manager/      # User-level configuration
│   └── programs/      # Application configs (emacs, neovim, git, zsh, etc.)
└── overlays/          # Nix package overlays
```

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- For macOS: [nix-darwin](https://github.com/LnL7/nix-darwin)

## Usage

### NixOS

```sh
sudo nixos-rebuild switch --flake ~/dev/repos/nixos-configuration#helios
```

### macOS

```sh
darwin-rebuild switch --flake ~/dev/repos/nixos-configuration#macos
```

## License

MIT
