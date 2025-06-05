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
    enable = !pkgs.stdenv.isDarwin;
    initExtra = "xset r rate 200 50";
  };

  xfconf = {
    enable = !pkgs.stdenv.isDarwin;
    settings = {
      xfce4-keyboard-shortcuts = {
        "/commands/custom/<Alt>F1" = null;
        "/commands/custom/<Alt>F2" = null;
        "/commands/custom/<Alt>F2/startup-notify" = null;
        "/commands/custom/<Alt>F3" = null;
        "/commands/custom/<Alt>F3/startup-notify" = null;
        "/commands/custom/<Alt>Print" = null;
        "/commands/custom/<Alt><Super>s" = null;
        "/commands/custom/HomePage" = null;
        "/commands/custom/override" = null;
        "/commands/custom/<Primary><Alt>Delete" = null;
        "/commands/custom/<Primary><Alt>Escape" = null;
        "/commands/custom/<Primary><Alt>f" = null;
        "/commands/custom/<Primary><Alt>l" = null;
        "/commands/custom/<Primary><Alt>t" = null;
        "/commands/custom/<Primary>Escape" = null;
        "/commands/custom/<Primary><Shift>Escape" = null;
        "/commands/custom/Print" = null;
        "/commands/custom/<Shift>Print" = null;
        "/commands/custom/<Super>" = null;
        "/commands/custom/<Super>p" = null;
        "/commands/custom/<Super>r" = null;
        "/commands/custom/<Super>r/startup-notify" = null;
        "/commands/custom/XF86Display" = null;
        "/commands/custom/XF86Mail" = null;
        "/commands/custom/XF86WWW" = null;
        "/commands/default/<Alt>F1" = null;
        "/commands/default/<Alt>F2" = null;
        "/commands/default/<Alt>F2/startup-notify" = null;
        "/commands/default/<Alt>F3" = null;
        "/commands/default/<Alt>F3/startup-notify" = null;
        "/commands/default/<Alt>Print" = null;
        "/commands/default/<Alt><Super>s" = null;
        "/commands/default/HomePage" = null;
        "/commands/default/<Primary><Alt>Delete" = null;
        "/commands/default/<Primary><Alt>Escape" = null;
        "/commands/default/<Primary><Alt>f" = null;
        "/commands/default/<Primary><Alt>l" = null;
        "/commands/default/<Primary><Alt>t" = null;
        "/commands/default/<Primary>Escape" = null;
        "/commands/default/<Primary><Shift>Escape" = null;
        "/commands/default/Print" = null;
        "/commands/default/<Shift>Print" = null;
        "/commands/default/<Super>e" = null;
        "/commands/default/<Super>p" = null;
        "/commands/default/<Super>r" = null;
        "/commands/default/<Super>r/startup-notify" = null;
        "/commands/default/XF86Display" = null;
        "/commands/default/XF86Mail" = null;
        "/commands/default/XF86WWW" = null;
        "/providers" = null;
        "/xfwm4/default/<Alt>Delete" = null;
        "/xfwm4/default/<Alt>F10" = null;
        "/xfwm4/default/<Alt>F11" = null;
        "/xfwm4/default/<Alt>F12" = null;
        "/xfwm4/default/<Alt>F4" = null;
        "/xfwm4/default/<Alt>F6" = null;
        "/xfwm4/default/<Alt>F7" = null;
        "/xfwm4/default/<Alt>F8" = null;
        "/xfwm4/default/<Alt>F9" = null;
        "/xfwm4/default/<Alt>Insert" = null;
        "/xfwm4/default/<Alt><Shift>Tab" = null;
        "/xfwm4/default/<Alt>space" = null;
        "/xfwm4/default/<Alt>Tab" = null;
        "/xfwm4/default/Down" = null;
        "/xfwm4/default/Escape" = null;
        "/xfwm4/default/Left" = null;
        "/xfwm4/default/<Primary><Alt>d" = null;
        "/xfwm4/default/<Primary><Alt>Down" = null;
        "/xfwm4/default/<Primary><Alt>End" = null;
        "/xfwm4/default/<Primary><Alt>Home" = null;
        "/xfwm4/default/<Primary><Alt>KP_1" = null;
        "/xfwm4/default/<Primary><Alt>KP_2" = null;
        "/xfwm4/default/<Primary><Alt>KP_3" = null;
        "/xfwm4/default/<Primary><Alt>KP_4" = null;
        "/xfwm4/default/<Primary><Alt>KP_5" = null;
        "/xfwm4/default/<Primary><Alt>KP_6" = null;
        "/xfwm4/default/<Primary><Alt>KP_7" = null;
        "/xfwm4/default/<Primary><Alt>KP_8" = null;
        "/xfwm4/default/<Primary><Alt>KP_9" = null;
        "/xfwm4/default/<Primary><Alt>Left" = null;
        "/xfwm4/default/<Primary><Alt>Right" = null;
        "/xfwm4/default/<Primary><Alt>Up" = null;
        "/xfwm4/default/<Primary>F1" = null;
        "/xfwm4/default/<Primary>F10" = null;
        "/xfwm4/default/<Primary>F11" = null;
        "/xfwm4/default/<Primary>F12" = null;
        "/xfwm4/default/<Primary>F2" = null;
        "/xfwm4/default/<Primary>F3" = null;
        "/xfwm4/default/<Primary>F4" = null;
        "/xfwm4/default/<Primary>F5" = null;
        "/xfwm4/default/<Primary>F6" = null;
        "/xfwm4/default/<Primary>F7" = null;
        "/xfwm4/default/<Primary>F8" = null;
        "/xfwm4/default/<Primary>F9" = null;
        "/xfwm4/default/<Primary><Shift><Alt>Left" = null;
        "/xfwm4/default/<Primary><Shift><Alt>Right" = null;
        "/xfwm4/default/<Primary><Shift><Alt>Up" = null;
        "/xfwm4/default/Right" = null;
        "/xfwm4/default/<Shift><Alt>Page_Down" = null;
        "/xfwm4/default/<Shift><Alt>Page_Up" = null;
        "/xfwm4/default/<Super>KP_Down" = null;
        "/xfwm4/default/<Super>KP_End" = null;
        "/xfwm4/default/<Super>KP_Home" = null;
        "/xfwm4/default/<Super>KP_Left" = null;
        "/xfwm4/default/<Super>KP_Next" = null;
        "/xfwm4/default/<Super>KP_Page_Up" = null;
        "/xfwm4/default/<Super>KP_Right" = null;
        "/xfwm4/default/<Super>KP_Up" = null;
        "/xfwm4/default/<Super>Tab" = null;
        "/xfwm4/default/Up" = null;
      };

      keyboards = {
        "/Default/KeyRepeat/Delay" = 200;
        "/Default/KeyRepeat/Rate" = 50;
      };
    };
  };

  home = {
    inherit username;

    stateVersion = "24.05";

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.anyenv/bin"
      "$HOME/.elan/bin"
      "$HOME/.volta/bin"
      "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
    ];

    language.base = "en_US.UTF-8";

    file = {
      ".config" = {
        source = ./.config;
        recursive = true;
      };
      ".claude/CLAUDE.md" = {
        source = ./ext/CLAUDE.md;
      };
      ".claude/settings.json" = {
        source = ./ext/claude-settings.json;
      };
    };

    # https://search.nixos.org/packages?channel=24.11
    packages =
      let
        cljstyle = pkgs.callPackage ./pkgs/cljstyle.nix { };

        # https://search.nixos.org/packages
        commonPackages = with pkgs; [
          babashka
          binutils
          cargo
          claude-code
          clj-kondo
          clojure
          coreutils
          deno
          devenv
          diffutils
          dig
          eask-cli
          ffmpeg
          file
          ghostscript
          ghq
          git-secrets
          gnumake
          gprolog
          imagemagick
          inetutils
          leiningen
          libgccjit
          minio
          mkcert
          mpv
          neil
          ngrok
          nix-output-monitor
          nkf
          nodejs
          parallel
          pdm
          pipx
          pnpm
          poetry
          postgresql
          python313
          rar
          rlwrap
          sbcl
          sqldef
          sqlite
          tailscale
          tig
          tokei
          tree
          unixtools.watch
          unzip
          volta
          zip
          zlib

          cljstyle
        ];

        linuxPackages = with pkgs; [
          burpsuite
          chromium
          dbeaver-bin
          firefox
          gnome-system-monitor
          gparted
          ollama
          pciutils
          qpdfview
          xsel
          jetbrains.idea-ultimate
          vlc
        ];

        macPackages = with pkgs; [ ];

        languageServers = with pkgs; [
          clojure-lsp
          typescript-language-server
          # nodePackages.graphql-language-service-cli
        ];

        inputPackages =
          [
            inputs.cljgen.packages.${system}.default
            inputs.nix-flake-clojure.packages.${system}.default
          ]
          ++ (
            if !pkgs.stdenv.isDarwin then
              [
                inputs.claude-desktop.packages.${system}.claude-desktop
              ]
            else
              [ ]
          );

      in
      commonPackages
      ++ (if pkgs.stdenv.isDarwin then macPackages else linuxPackages)
      ++ languageServers
      ++ inputPackages;
  };

  programs = {
    # https://nix-community.github.io/home-manager/options.xhtml
    home-manager.enable = true;

    alacritty.enable = true;
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

    atuin = import ./programs/atuin.nix;
    bash = import ./programs/bash.nix;
    direnv = import ./programs/direnv.nix;
    emacs = import ./programs/emacs.nix (pkgs);
    git = import ./programs/git.nix;
    neovim = import ./programs/neovim.nix;
    zsh = import ./programs/zsh.nix;
  };
}
