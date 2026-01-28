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

## Maintenance

### Update flake inputs aligned with binary cache

To avoid long build times, update nixpkgs to match the revision used by numtide's binary cache:

```sh
REV=$(curl -sL https://raw.githubusercontent.com/numtide/llm-agents.nix/main/flake.lock | jq -r '.nodes.nixpkgs.locked.rev')
nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/${REV}
```

This ensures that packages will be fetched from cache instead of being built locally.

Binary caches configured in `nixos/configuration.nix`:
- `https://nix-community.cachix.org` - Nix community packages
- `https://emacs-ci.cachix.org` - Multiple Emacs versions
- `https://cache.numtide.com` - llm-agents.nix packages

## License

MIT
