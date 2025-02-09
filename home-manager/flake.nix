{
  description = "Home Manager configuration of conao";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
      system = "aarch64-darwin";
      username = "conao";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations.${username} = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            inputs.emacs-overlay.overlay
          ];
        };

        extraSpecialArgs = {
          inherit system username inputs;
        };

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
          inputs.mac-app-util.homeManagerModules.default
          ./home.nix
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };

      darwinConfigurations.toyokumo = inputs.nix-darwin.lib.darwinSystem {
        inherit system;

        modules = [ ./nix-darwin ];
      };

      formatter.aarch64-darwin = pkgs.nixfmt-rfc-style;
    };
}
