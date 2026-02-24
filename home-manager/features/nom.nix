{ pkgs, ... }:
let
  wrapper = ''
    nix() {
      case "''${1:-}" in
        build|develop|shell)
          command nom "$@"
          ;;
        *)
          command nix "$@"
          ;;
      esac
    }
  '';
in
{
  home.packages = [
    pkgs.nix-output-monitor
  ];

  programs.bash.initExtra = wrapper;
  programs.zsh.initContent = wrapper;
}
