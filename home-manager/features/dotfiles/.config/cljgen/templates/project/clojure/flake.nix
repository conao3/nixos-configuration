{
  description = "Generate project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    clj-nix = {
      url = "github:jlesquembre/clj-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      clj-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        cljpkgs = clj-nix.packages."${system}";
      in
      {
        packages = rec {
          default = native;

          jar = cljpkgs.mkCljBin {
            projectSrc = ./.;
            name = "com.github.conao3/{{repo-name}}";
            main-ns = "{{repo-name}}.core";
            jdkRunner = pkgs.jdk17_headless;
          };

          native = cljpkgs.mkGraalBin {
            cljDrv = self.packages."${system}".jar;
          };
        };

        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.clojure
            pkgs.openjdk
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
