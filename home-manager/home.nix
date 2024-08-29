{ config, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      vim
      zsh
      git
      tmux
    ];
  };

  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      userName = "conao3";
      userEmail = "conao3@gmail.com";
    };
    zsh = {
      enable = true;
    };
  };

  home.stateVersion = "24.05";
}
