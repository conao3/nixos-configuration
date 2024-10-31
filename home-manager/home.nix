{
  config,
  pkgs,
  system,
  username,
  inputs,
  ...
}:

{
  home = {
    inherit username;

    stateVersion = "24.05";
    homeDirectory = "/Users/${username}";

    sessionVariables = {
      SDKMAN_DIR = "/opt/homebrew/opt/sdkman-cli/libexec";
    };

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
        aws-sam-cli
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

        cljstyle
        emacs-git
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

    neovim = {
      enable = true;

      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/editors/vim/plugins/vim-plugin-names
      plugins = with pkgs.vimPlugins; [
        nvim-lspconfig
        {
          plugin = fzf-vim;
          config = ''
            " let $FZF_DEFAULT_COMMAND = "fd --type f --hidden -E '.git'"
            nnoremap <leader>t  :FZF<cr>
            nnoremap <leader>sp :Rg<cr>
            nnoremap <leader>,  :Buffers<cr>
            nnoremap <leader>bb :Buffers<cr>
            nnoremap <leader>bd :bd<cr>
            nnoremap <leader>ss :BLines<cr>
            nnoremap <leader>bB :Windows<cr>
            nnoremap <leader>ff :Files<cr>
            nnoremap <leader>ht :Colors<cr>
            nnoremap <leader>hh :Helptags<cr>
            nnoremap <leader>gg :Changes<cr>
            nnoremap <leader>gl :Commits<cr>
            nnoremap <leader>oT :terminal<cr>

            nnoremap <leader>hrr :source ~/.config/nvim/init.lua<cr>
          '';
        }
      ];
    };

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
