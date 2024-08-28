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

  home.stateVersion = "23.11";
  programs.home-manager.enable = true;
}
