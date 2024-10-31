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
      extraConfig = ''
        set autoindent

        let s:jetpackfile = stdpath('data') .. '/site/pack/jetpack/opt/vim-jetpack/plugin/jetpack.vim'
        let s:jetpackurl = "https://raw.githubusercontent.com/tani/vim-jetpack/master/plugin/jetpack.vim"
        if !filereadable(s:jetpackfile)
          call system(printf('curl -fsSLo %s --create-dirs %s', s:jetpackfile, s:jetpackurl))
        endif

        packadd vim-jetpack
        call jetpack#begin()
        Jetpack 'tani/vim-jetpack', {'opt': 1} "bootstrap
        Jetpack 'junegunn/fzf.vim'
        Jetpack 'vim-denops/denops.vim'
        Jetpack 'vim-denops/denops-helloworld.vim'
        Jetpack 'vim-skk/skkeleton'
        Jetpack 'kei-s16/skkeleton-azik-kanatable'
        Jetpack 'yasunori0418/statusline_skk.vim'
        Jetpack 'itchyny/lightline.vim'
        Jetpack 'prabirshrestha/vim-lsp'
        Jetpack 'mattn/vim-lsp-settings'
        Jetpack 'ctrlpvim/ctrlp.vim'
        Jetpack 'nvim-lua/plenary.nvim'
        Jetpack 'nvim-telescope/telescope.nvim'
        Jetpack 'liquidz/elin'
        call jetpack#end()

        for name in jetpack#names()
          if !jetpack#tap(name)
            call jetpack#sync()
            break
          endif
        endfor

        "skkeleton
        call skkeleton#azik#add_table('us')
        call skkeleton#config(
          \ {
          \   'globalDictionaries': ['~/.skk/SKK-JISYO.L'],
          \   'kanaTable': 'azik',
          \   'eggLikeNewline': v:true
          \ })

        imap <C-j> <Plug>(skkeleton-enable)
        cmap <C-j> <Plug>(skkeleton-enable)
        imap <C-l> <Plug>(skkeleton-disable)
        cmap <C-l> <Plug>(skkeleton-disable)

        "statusline_skk
        let g:lightline = {
          \ 'active': {
          \   'left': [ [ 'mode', 'paste', 'skk_mode' ],
          \             [ 'readonly', 'filename', 'modified' ] ]
          \   },
          \ 'component_function': {
          \   'skk_mode': 'statusline_skk#mode',
          \   },
          \ }

        "lightline
        set laststatus=2

        "telescope
        nnoremap <leader>ff <cmd>Telescope find_files<cr>
        nnoremap <leader>fg <cmd>Telescope live_grep<cr>
        nnoremap <leader>fb <cmd>Telescope buffers<cr>
        nnoremap <leader>fh <cmd>Telescope help_tags<cr>

        "elin
        let g:elin_enable_default_key_mappings = v:true
      '';
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
