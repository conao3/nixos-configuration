# https://home-manager-options.extranix.com/?query=&release=release-24.05
{ ... }:
{
  imports = [
    ./base.nix
    ./vars.nix
    ./pkgs.nix
    ./files.nix
    ./xsession.nix
    ./xfconf.nix
    ./services.nix
    ./programs/programs-enable.nix
    ./programs/atuin.nix
    ./programs/bash.nix
    ./programs/direnv.nix
    ./programs/emacs.nix
    ./programs/git.nix
    ./programs/neovim.nix
    ./programs/zsh.nix
  ];
}
