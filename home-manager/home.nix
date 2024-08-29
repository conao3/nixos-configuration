{ config, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      emacs
      vim
      tmux
      chromium
      firefox
      tree
      tig
      ghq
      _1password-gui
      atuin
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
