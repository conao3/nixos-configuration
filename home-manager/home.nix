{ config, pkgs, ... }:
{
  home = {
    packages = let
      cljstyle = pkgs.callPackage ./nixpkgs/cljstyle.nix {};
    in with pkgs; [
      _1password-gui
      clj-kondo
      cljstyle
      devenv
      emacs
      ghq
      mkcert
      nix-prefetch-github
      tig
      tree
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
      ignores = [
        ".envrc"
        "devenv.nix"
        "devenv.yaml"
        ".devenv*"
        "devenv.local.nix"
        ".direnv"
        ".pre-commit-config.yaml"
      ];
    };
  };

  home.stateVersion = "24.05";
}
