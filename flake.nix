{
  description = "conao3's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
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
  };

  outputs =
    { ... }@inputs:
    let
      system = "x86_64-linux";
      username = "conao";
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ inputs.emacs-overlay.overlay ];
      };
    in
    {
      nixosConfigurations = {
        helios = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./nixos/configuration.nix
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = { inherit pkgs system username inputs; };
              # home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.conao = import ./home-manager/home.nix;
            }
          ];
        };
      };
      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
    };
}
