{ config, pkgs, ... }:

{
  home = {
    stateVersion = "24.05";
    username = "conao";
    homeDirectory = "/Users/conao";

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

    packages = let
      cljstyle = pkgs.callPackage ./nixpkgs/cljstyle.nix {};
    in with pkgs; [
      # _1password-gui
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
    # chromium.enable = true;
    # firefox.enable = true;
    gpg.enable = true;
    htop.enable = true;
    java.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    tmux.enable = true;
    vim.enable = true;
    vscode.enable = true;

    zsh = {
      enable = true;
      profileExtra =
        ''
eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(anyenv init -)"
'';
      initExtra =
        ''
[[ -s "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh" ]] && source "/opt/homebrew/opt/sdkman-cli/libexec/bin/sdkman-init.sh"
'';
      envExtra =
        ''
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
