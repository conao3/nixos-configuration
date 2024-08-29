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

  programs.git = {
    enable = true;
    userName = "conao3";
    userEmail = "conao3@gmail.com";
  };
  programs.zsh = {
    enable = true;
  };

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}
