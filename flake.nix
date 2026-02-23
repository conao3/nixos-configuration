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
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
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
    gitm = {
      url = "github:conao3/bash-gitm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pype = {
      url = "github:conao3/python-pype";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-fetch-usage-limit = {
      url = "github:conao3/rust-fetch-usage-limit";
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
        { pkgs, ... }:
        {
          treefmt.programs.nixfmt.enable = true;

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              gnumake
              sops
              age
            ];
          };
        };

      flake =
        let
          username = "conao";
          linuxSystem = "x86_64-linux";
          macSystem = "aarch64-darwin";

          commonNixpkgsConfig = {
            overlays = [
              inputs.emacs-overlay.overlays.default
              (import ./overlays/go.nix)
            ];
            config.permittedInsecurePackages = [
              "googleearth-pro-7.3.6.10201"
            ];
          };

          mkNixosSystem =
            hostname:
            inputs.nixpkgs.lib.nixosSystem {
              system = linuxSystem;
              specialArgs = { inherit inputs; };
              modules = [
                ./nixos/configuration.nix
                ./hosts/${hostname}
                { nixpkgs = commonNixpkgsConfig; }
                inputs.home-manager.nixosModules.home-manager
                {
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    backupFileExtension = "backup";
                    extraSpecialArgs = {
                      inherit username inputs;
                      system = linuxSystem;
                    };
                    users.${username} = import ./home-manager/home.nix;
                    sharedModules = [
                      (
                        { lib, ... }:
                        {
                          home.homeDirectory = lib.mkForce "/home/${username}";
                        }
                      )
                    ];
                  };
                }
              ];
            };
        in
        {
          nixosConfigurations = {
            "conao-nixos-helios" = mkNixosSystem "helios";
            "conao-nixos-eos" = mkNixosSystem "eos";
            "conao-nixos-agent" = inputs.nixpkgs.lib.nixosSystem {
              system = linuxSystem;
              specialArgs = { inherit inputs; };
              modules = [
                ./hosts/agent-vm
                { nixpkgs.config.allowUnfree = true; }
                inputs.home-manager.nixosModules.home-manager
                {
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    backupFileExtension = "backup";
                    extraSpecialArgs = { inherit inputs; };
                    sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
                    users.conao = import ./hosts/agent-vm/home.nix;
                  };
                }
              ];
            };
          };

          darwinConfigurations = {
            macos = inputs.nix-darwin.lib.darwinSystem {
              system = macSystem;
              specialArgs = { inherit username inputs; };
              modules = [
                ./darwin/configuration.nix
                {
                  nixpkgs.overlays = [
                    (import ./overlays/go.nix)
                  ];
                }
                inputs.home-manager.darwinModules.home-manager
                {
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    backupFileExtension = "backup";
                    extraSpecialArgs = {
                      inherit username inputs;
                      system = macSystem;
                    };
                    users.${username} = import ./home-manager/home.nix;
                    sharedModules = [
                      (
                        { lib, ... }:
                        {
                          home.homeDirectory = lib.mkForce "/Users/${username}";
                        }
                      )
                    ];
                  };
                }
              ];
            };
          };
        };
    };
}
