{ config, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      emacs
      tree
      tig
      ghq
      _1password-gui
    ];
  };

  programs = {
    home-manager.enable = true;
    atuin.enable = true;
    awscli.enable = true;
    bat.enable = true;
    chromium.enable = true;
    firefox.enable = true;
    gpg.enable = true;
    htop.enable = true;
    java.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    tmux.enable = true;
    vim.enable = true;
    vscode.enable = true;
    zsh.enable = true;

    git = {
      enable = true;
      userName = "conao3";
      userEmail = "conao3@gmail.com";
    };
  };

  home.stateVersion = "24.05";
}
