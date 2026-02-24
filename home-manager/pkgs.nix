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
        # keep-sorted start
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
        gogcli
        imagemagick
        inetutils
        libgccjit
        linear-cli
        neil
        ngrok
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
        # keep-sorted end
      ];

      linuxPackages = with pkgs; [
        # keep-sorted start
        (mpv.override { yt-dlp = pkgs.yt-dlp.override { javascriptSupport = false; }; })
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
        ollama
        pciutils
        pencil
        qpdfview
        steam-run
        telegram-desktop
        vlc
        xclip
        xsel
        # keep-sorted end
      ];

      macPackages = with pkgs; [
        # keep-sorted start
        gnumake
        pngpaste
        volta
        # keep-sorted end
      ];

      shogiPackages = with pkgs; [
        # keep-sorted start
        apery
        gnushogi
        shogihome
        yaneuraou
        # keep-sorted end
      ];

      languageServers = with pkgs; [
        # keep-sorted start
        clojure-lsp
        emacs-lsp-booster
        nixd
        # nodePackages.graphql-language-service-cli
        # keep-sorted end
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
          # keep-sorted start
          agent-browser
          agent-deck
          auto-claude
          beads
          catnip
          ck
          claude-code
          claude-code-acp
          codex
          codex-acp
          copilot-language-server
          eca
          # gastown
          happy-coder
          # TODO: https://github.com/Dicklesworthstone/mcp_agent_mail
          # TODO: https://github.com/steveyegge/efrit
          vibe-kanban
          workmux
          zeroclaw
          # keep-sorted end
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
