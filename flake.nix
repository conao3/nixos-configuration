{
  description = "conao3's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts"; # has no nixpkgs dependency
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cljgen = {
      url = "github:conao3/clojure-cljgen";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flake-clojure = {
      url = "github:conao3-playground/nix-flake-clojure";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        { config, pkgs, ... }:
        {
          treefmt.programs.nixfmt.enable = true;
        };

      flake =
        let
          username = "conao";

          linuxSystem = "x86_64-linux";
          macSystem = "aarch64-darwin";

          mkPkgs =
            system:
            import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
              overlays = [ inputs.emacs-overlay.overlay ];
            };

          mkHomeConfiguration =
            { system, pkgs }:
            {
              extraSpecialArgs = {
                inherit
                  pkgs
                  system
                  username
                  inputs
                  ;
              };
              useUserPackages = true;
              backupFileExtension = "backup";
              users.${username} = import ./home-manager/home.nix;
            };
        in
        {
          nixosConfigurations = {
            helios = inputs.nixpkgs.lib.nixosSystem {
              system = linuxSystem;
              modules = [
                ./nixos/configuration.nix
                ./hosts/helios
                inputs.home-manager.nixosModules.home-manager
                {
                  home-manager = mkHomeConfiguration {
                    system = linuxSystem;
                    pkgs = mkPkgs linuxSystem;
                  };
                }
              ];
            };
          };

          darwinConfigurations = {
            macos = inputs.nix-darwin.lib.darwinSystem {
              system = macSystem;
              modules = [
                ./darwin/configuration.nix
                inputs.home-manager.darwinModules.home-manager
                {
                  home-manager = mkHomeConfiguration {
                    system = macSystem;
                    pkgs = mkPkgs macSystem;
                  };
                }
              ];
            };
          };
        };
    };
}
