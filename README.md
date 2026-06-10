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
├── flake/             # flake-parts modules (treefmt, etc.)
├── common/            # Modules shared between NixOS and nix-darwin
├── darwin/            # macOS (nix-darwin) configuration
├── nixos/             # NixOS-specific modules
├── hosts/             # Machine-specific configurations
│   ├── helios/        # NixOS workstation
│   ├── eos/           # NixOS machine
│   └── agent-vm/      # Self-contained QEMU VM for agents
├── home-manager/      # home-manager modules
│   ├── base.nix       # username, stateVersion, sessionPath
│   ├── pkgs.nix       # user package list
│   └── features/      # one module per feature (emacs, neovim, git, zsh, etc.)
├── home-profile/      # profile = user + feature module list, per host
├── pkgs/              # custom package definitions
├── overlays/          # Nix package overlays
└── secrets/           # sops-encrypted secrets
```

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- For macOS: [nix-darwin](https://github.com/LnL7/nix-darwin)

### Private `nix-flakes` Input

This flake expects a sibling Git repository at `../nix-flakes`. The author's checkout uses the
private `conao3/nix-flakes` repository there. Public users can satisfy the same interface with the
public stub repository:

```sh
git clone https://github.com/conao3/nix-flakes-public ../nix-flakes
nix flake lock --update-input nix-flakes
```

The public stub only needs to provide files imported by this repository, such as
`nix-flakes-registry.nix`.

## Usage

Apply the configuration for the current machine (NixOS and macOS are detected automatically):

```sh
make switch
```

Equivalent raw commands:

```sh
sudo nixos-rebuild switch --flake .            # NixOS
sudo -H nix run nix-darwin -- switch --flake . # macOS
```

## Maintenance

### Update flake inputs aligned with binary cache

To avoid long build times, update nixpkgs to match the revision used by numtide's binary cache:

```sh
make update
```

This ensures that packages will be fetched from cache instead of being built locally.

Binary caches configured in `nixos/configuration.nix`:
- `https://nix-community.cachix.org` - Nix community packages
- `https://emacs-ci.cachix.org` - Multiple Emacs versions
- `https://cache.numtide.com` - llm-agents.nix packages

## License

MIT
