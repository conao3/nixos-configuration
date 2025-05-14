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

          # Create package sets with overlays
          mkPkgs =
            system:
            import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
              overlays = [ inputs.emacs-overlay.overlay ];
            };

          linuxPkgs = mkPkgs linuxSystem;
          macPkgs = mkPkgs macSystem;

          # Import common modules
          mkHomeManagerConfig = import ./lib/home-manager-common.nix;
          nixCommon = import ./lib/nix-common.nix;

          # Import library functions
          inherit (inputs.home-manager.lib) hm;
        in
        {
          nixosConfigurations = {
            helios = inputs.nixpkgs.lib.nixosSystem {
              system = linuxSystem;
              specialArgs = { inherit inputs username; };
              modules = [
                ./nixos/configuration.nix
                ./hosts/helios

                # Add common Nix settings
                {
                  imports = [
                    (nixCommon {
                      inherit linuxPkgs;
                      pkgs = linuxPkgs;
                      isNixOS = true;
                    })
                  ];
                }

                # Add home-manager
                inputs.home-manager.nixosModules.home-manager
                {
                  home-manager = mkHomeManagerConfig {
                    inherit username inputs;
                    system = linuxSystem;
                    mainPkgs = linuxPkgs;
                    forMacos = false;
                  };
                }
              ];
            };
          };

          darwinConfigurations = {
            macos = inputs.nix-darwin.lib.darwinSystem {
              system = macSystem;
              specialArgs = { inherit inputs username; };
              modules = [
                ./darwin/configuration.nix

                # Add common Nix settings
                {
                  imports = [
                    (nixCommon {
                      inherit macPkgs;
                      pkgs = macPkgs;
                      isNixOS = false;
                    })
                  ];
                }

                # Add macOS-specific modules
                inputs.mac-app-util.darwinModules.default

                # Add home-manager
                inputs.home-manager.darwinModules.home-manager
                {
                  home-manager = mkHomeManagerConfig {
                    inherit username inputs;
                    system = macSystem;
                    mainPkgs = macPkgs;
                    forMacos = true;
                  };
                }
              ];
            };
          };
        };
    };
}
