{
  config,
  pkgs,
  system,
  username,
  inputs,
  ...
}:

{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  home = {
    inherit username;

    stateVersion = "24.05";
    homeDirectory = "/Users/${username}";

    sessionVariables = {
      SDKMAN_DIR = "/opt/homebrew/opt/sdkman-cli/libexec";
    };

    sessionPath = [
      "/Applications/Emacs.app/Contents/MacOS/bin"
      "/Applications/Emacs.app/Contents/MacOS"
      "$HOME/.local/bin"
      "$HOME/.anyenv/bin"
      "$HOME/.elan/bin"
      "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
    ];

    language.base = "en_US.UTF-8";

    packages =
      let
        cljstyle = pkgs.callPackage ./nixpkgs/cljstyle.nix { };
      in
      with pkgs;
      [
        autoconf
        aws-sam-cli
        babashka
        binutils
        clj-kondo
        cljstyle
        clojure
        clojure-lsp
        coreutils
        deno
        devenv
        diffutils
        emacs
        ffmpeg
        ghq
        imagemagick
        jansson
        leiningen
        libgccjit
        minio
        mkcert
        moreutils
        ncurses
        ngrok
        nix-prefetch-github
        nkf
        python3
        rlwrap
        sqlite
        tailscale
        tig
        tokei
        tree
      ]
      ++ [
        inputs.cljgen.packages.${system}.default
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
    neovim.enable = true;
    ripgrep.enable = true;
    tmux.enable = true;
    vim.enable = true;
    vscode.enable = true;

    bash = {
      enable = true;
      profileExtra = ''
        . "$HOME/.cargo/env"
        eval "$(anyenv init -)"
        [[ -s "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh" ]] && source "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh"
      '';
    };

    zsh = {
      enable = true;
      profileExtra = ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
        eval "$(anyenv init -)"
      '';
      initExtra = ''
        [[ -s "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh" ]] && source "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh"
      '';
      envExtra = ''
        . "$HOME/.cargo/env"
      '';
    };

    git = {
      enable = true;
      lfs.enable = true;

      userName = "conao3";
      userEmail = "conao3@gmail.com";

      ignores = [
        # macOS
        ".DS_Store"
        "._*"

        # Emacs
        "*~"
        ".#*"
        "\#*"
        "*_flymake.*"
        "flycheck_*"

        # Vim
        "*.swp"

        # Editors
        ".vscode"
        ".idea"

        # Tags
        "GPATH"
        "GR?TAGS"

        # Misc
        ".env"
        "*.conao3"
        "*.orig"
      ];

      extraConfig = {
        core = {
          quotepath = false;
          fsmonitor = true;
        };
        init = {
          defaultBranch = "master";
        };
        fetch = {
          prune = true;
        };
        rebase = {
          autoStash = true;
          autoSquash = true;
        };
        color = {
          ui = "auto";
          status = "auto";
          diff = "auto";
          branch = "auto";
          interactive = "auto";
          grep = "auto";
        };
        rerere = {
          enabled = true;
        };
      };
    };
  };
}
