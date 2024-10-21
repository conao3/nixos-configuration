{ config, pkgs, ... }:

{
  home = {
    stateVersion = "24.05";
    username = "conao";
    homeDirectory = "/Users/conao";

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
export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"

export PATH="/Applications/Emacs.app/Contents/MacOS/bin:$PATH"
export PATH="/Applications/Emacs.app/Contents/MacOS:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.elan/bin:$PATH"
export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
export LANG=en_US.UTF-8

. ~/.nix-profile/etc/profile.d/hm-session-vars.sh
'';
      initExtra =
        ''
export SDKMAN_DIR="/opt/homebrew/opt/sdkman-cli/libexec"
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
