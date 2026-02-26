{
  description = "dashboard development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nodejs_24
              pnpm
              python3
            ];
          };

          frontend = pkgs.mkShell {
            packages = with pkgs; [
              nodejs_24
              pnpm
            ];
          };

          backend = pkgs.mkShell {
            packages = with pkgs; [
              python3
            ];
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          dashboard = pkgs.writeShellApplication {
            name = "dashboard";
            runtimeInputs = with pkgs; [
              nodejs_24
              pnpm
              python3
            ];
            text = ''
              set -euo pipefail
              export DASHBOARD_BACKEND_HOST=127.0.0.1
              export DASHBOARD_BACKEND_PORT=9411
              export DASHBOARD_DEV_BACKEND_PORT=9411

              python3 backend.py &
              backend_pid=$!
              trap 'kill "$backend_pid" 2>/dev/null || true' EXIT INT TERM

              cd frontend
              [ -d node_modules ] || pnpm install --frozen-lockfile
              pnpm dev
            '';
          };
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          dev = {
            type = "app";
            program = "${pkgs.lib.getExe self.packages.${system}.dashboard}";
          };
        }
      );
    };
}
