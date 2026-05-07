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
      claudeDesktopSrc = inputs.claude-desktop;
      patchy-cnb = pkgs.callPackage (claudeDesktopSrc + "/pkgs/patchy-cnb.nix") { };
      claude-desktop = pkgs.callPackage (claudeDesktopSrc + "/pkgs/claude-desktop.nix") {
        inherit patchy-cnb;
        nodePackages = {
          inherit (pkgs) asar;
        };
      };
      claude-desktop-with-fhs = pkgs.buildFHSEnv {
        name = "claude-desktop";
        targetPkgs = pkgs':
          with pkgs'; [
            docker
            glibc
            openssl
            nodejs
            uv
          ];
        runScript = "${claude-desktop}/bin/claude-desktop";
        extraInstallCommands = ''
          mkdir -p $out/share/applications
          cp ${claude-desktop}/share/applications/claude.desktop $out/share/applications/

          mkdir -p $out/share/icons
          cp -r ${claude-desktop}/share/icons/* $out/share/icons/
        '';
      };
      chrome-devtools = pkgs.callPackage ../pkgs/chrome-devtools.nix { };
      cli-proxy-api-management-center = pkgs.callPackage ../pkgs/cli-proxy-api-management-center.nix { };
      ghq = pkgs.callPackage ../pkgs/ghq.nix { };
      clojure-mcp-light = pkgs.callPackage ../pkgs/clojure-mcp-light.nix { src = inputs.clojure-mcp-light; };
      linear-cli = pkgs.callPackage ../pkgs/linear-cli.nix { };
      mo = pkgs.callPackage ../pkgs/mo.nix { };
      pencil-dev = pkgs.callPackage ../pkgs/pencil-dev.nix { };
      symphony = pkgs.callPackage ../pkgs/symphony.nix { beamPackages = pkgs.beam.packages.erlang_28; };
      gogcli = pkgs.callPackage ./pkgs/gogcli.nix { inherit system; };
      devo = pkgs.rustPlatform.buildRustPackage {
        pname = "devo";
        version = "0.1.0";
        src = inputs.devo;
        cargoLock.lockFile = inputs.devo + "/Cargo.lock";
      };

      # https://search.nixos.org/packages
      commonPackages = with pkgs; [
        # keep-sorted start
        babashka
        bottom
        chrome-devtools
        clj-kondo
        cli-proxy-api-management-center
        clojure-mcp-light
        coreutils
        devenv
        diffutils
        dig
        duckdb
        eask-cli
        ffmpeg
        file
        ghostscript
        ghq
        git-secrets
        git-wt
        gogcli
        imagemagick
        inetutils
        libgccjit
        linear-cli
        mo
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
        symphony
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
        binutils
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
        pencil-dev
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
        # shogihome # electron build broken: 39-angle-patchdir.patch fails to apply
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
        inputs.rust-llm-quota.packages.${system}.default
        devo
        pkgs.nodejs_24 # vibe-kanban requires npx
        pkgs.pnpm_10
      ]
      ++ (
        if pkgs.stdenv.isDarwin then
          [
            # inputs.arto.packages.${system}.default  # arto build broken (e0663d4)
          ]
        else
          [
            claude-desktop-with-fhs
          ]
      )
      ++ (
        with inputs.llm-agents.packages.${system};
        [
          # keep-sorted start
          agent-browser
          agent-deck
          auto-claude
          catnip
          ck
          claude-agent-acp
          codex-acp
          copilot-language-server
          # eca
          # gastown
          happy-coder
          # TODO: https://github.com/Dicklesworthstone/mcp_agent_mail
          # TODO: https://github.com/steveyegge/efrit
          vibe-kanban
          workmux
          # keep-sorted end
        ]
      );

    in
    commonPackages
    ++ (if pkgs.stdenv.isDarwin then macPackages else linuxPackages)
    ++ languageServers
    ++ inputPackages
    ++ shogiPackages;
}
