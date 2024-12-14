{
  config,
  pkgs,
  system,
  username,
  inputs,
  ...
}:

# https://home-manager-options.extranix.com/?query=&release=release-24.05
{
  xsession = {
    enable = true;
    initExtra = "xset r rate 200 50";
  };

  home = {
    inherit username;

    stateVersion = "24.05";
    homeDirectory = "/home/${username}";

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.anyenv/bin"
      "$HOME/.elan/bin"
      "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
    ];

    language.base = "en_US.UTF-8";

    file = {
      ".config" = {
        source = ./.config;
        recursive = true;
      };
    };

    packages =
      let
        cljstyle = pkgs.callPackage ./nixpkgs/cljstyle.nix { };
      in
      with pkgs;
      [
        # aws-sam-cli
        babashka
        binutils
        clj-kondo
        clojure
        clojure-lsp
        coreutils
        deno
        devenv
        diffutils
        ffmpeg
        ghostscript
        ghq
        git-secrets
        imagemagick
        leiningen
        libgccjit
        minio
        mkcert
        moreutils
        ngrok
        nkf
        ollama
        python3
        rlwrap
        sqlite
        tailscale
        tig
        tokei
        tree
        firefox
        gnome-system-monitor
        gparted
        vlc
	unzip

        cljstyle
        # emacs-git
      ]
      ++ [
        inputs.cljgen.packages.${system}.default
        inputs.nix-flake-clojure.packages.${system}.default
      ];
  };

  programs = {
    home-manager.enable = true;
    # chromium.enable = true;
    # firefox.enable = true;
    # foot.enable = true;
    alacritty.enable = true;
    atuin.enable = true;
    awscli.enable = true;
    bat.enable = true;
    eza.enable = true;
    fzf.enable = true;
    gh.enable = true;
    go.enable = true;
    gpg.enable = true;
    htop.enable = true;
    java.enable = true;
    jq.enable = true;
    lsd.enable = true;
    ripgrep.enable = true;
    tmux.enable = true;
    vim.enable = true;
    vscode.enable = true;

    bash = import ./programs/bash.nix;
    direnv = import ./programs/direnv.nix;
    git = import ./programs/git.nix;
    neovim = import ./programs/neovim.nix;
    zsh = import ./programs/zsh.nix;
    emacs = {
      enable = true;
      package = pkgs.emacs-git;
    };
  };
}
