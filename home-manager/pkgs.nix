{
  lib,
  pkgs,
  system,
  inputs,
  ...
}:
{
  # https://search.nixos.org/packages?channel=24.11
  home.packages =
    let
      linear-cli = pkgs.callPackage ../pkgs/linear-cli.nix { };
      gogcli = pkgs.callPackage ./pkgs/gogcli.nix { inherit system; };

      # https://search.nixos.org/packages
      commonPackages = with pkgs; [
        binutils
        clj-kondo
        coreutils
        diffutils
        dig
        duckdb
        # eask-cli
        ffmpeg
        file
        ghostscript
        ghq
        git-secrets
        imagemagick
        inetutils
        libgccjit
        neil
        ngrok
        nix-output-monitor
        nkf
        obsidian
        parallel
        postgresql
        rar
        rlwrap
        sqldef
        sqlite
        tig
        tokei
        tree
        unixtools.watch
        unzip
        zip
        zlib

        # cljstyle
        gogcli
        linear-cli
      ];

      linuxPackages = with pkgs; [
        burpsuite
        chromium
        dbeaver-bin
        firefox
        gimp
        gnome-system-monitor
        google-chrome
        googleearth-pro
        gparted
        logseq
        mpv
        ollama
        pciutils
        pencil
        qpdfview
        steam-run
        telegram-desktop
        vlc
        xclip
        xsel
      ];

      macPackages = with pkgs; [
        gnumake
        pngpaste
        volta
      ];

      shogiPackages = with pkgs; [
        shogihome
        yaneuraou
        apery
        gnushogi
      ];

      languageServers = with pkgs; [
        clojure-lsp
        emacs-lsp-booster
        nixd
        # nodePackages.graphql-language-service-cli
      ];

      inputPackages = [
        # inputs.cljgen.packages.${system}.default
        # inputs.nix-flake-clojure.packages.${system}.default
        inputs.gitm.packages.${system}.default
        inputs.pype.packages.${system}.default
        pkgs.nodejs_24 # vibe-kanban requires npx
      ]
      ++ (
        if !pkgs.stdenv.isDarwin then
          [
            inputs.claude-desktop.packages.${system}.claude-desktop-with-fhs
          ]
        else
          [ ]
      )
      ++ (
        with inputs.llm-agents.packages.${system};
        [
          codex
          claude-code
          zeroclaw
          vibe-kanban
          auto-claude
          claude-code-acp
          codex-acp
          # TODO: https://github.com/Dicklesworthstone/mcp_agent_mail
          # TODO: https://github.com/steveyegge/efrit
          beads
          # gastown
          agent-browser
          agent-deck
          ck
          workmux
          eca
          happy-coder
          catnip
          copilot-language-server
        ]
        ++ lib.optional pkgs.stdenv.isLinux coding-agent-search
      );

    in
    commonPackages
    ++ (if pkgs.stdenv.isDarwin then macPackages else linuxPackages)
    ++ languageServers
    ++ inputPackages
    ++ shogiPackages;
}
