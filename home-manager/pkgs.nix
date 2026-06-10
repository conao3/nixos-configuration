{
  pkgs,
  system,
  inputs,
  ...
}:
{
  # https://search.nixos.org/packages?channel=24.11
  home.packages =
    let
      claude-desktop-with-fhs = pkgs.callPackage ../pkgs/claude-desktop-fhs.nix {
        src = inputs.claude-desktop;
      };
      chrome-devtools = pkgs.callPackage ../pkgs/chrome-devtools.nix { };
      cli-proxy-api-management-center = pkgs.callPackage ../pkgs/cli-proxy-api-management-center.nix { };
      ghq = pkgs.callPackage ../pkgs/ghq.nix { };
      ghq-sync = pkgs.callPackage ../pkgs/ghq-sync.nix { inherit ghq; };
      clojure-mcp-light = pkgs.callPackage ../pkgs/clojure-mcp-light.nix {
        src = inputs.clojure-mcp-light;
      };
      linear-cli = pkgs.callPackage ../pkgs/linear-cli.nix { };
      lightpanda = pkgs.callPackage ../pkgs/lightpanda.nix { };
      mo = pkgs.callPackage ../pkgs/mo.nix { };
      portless = pkgs.callPackage ../pkgs/portless.nix { };
      symphony = pkgs.callPackage ../pkgs/symphony.nix { beamPackages = pkgs.beam.packages.erlang_28; };
      claude-app-server = pkgs.callPackage ../pkgs/claude-app-server.nix { };
      gogcli = pkgs.callPackage ../pkgs/gogcli.nix { inherit system; };
      devo = pkgs.rustPlatform.buildRustPackage {
        pname = "devo";
        version = "0.1.0";
        src = inputs.devo;
        cargoLock.lockFile = inputs.devo + "/Cargo.lock";
      };
      wrangler = pkgs.writeShellScriptBin "wrangler" ''
        exec ${pkgs.nodejs_24}/bin/npx --yes wrangler@4.62.0 "$@"
      '';
      inherit (pkgs.callPackage ../pkgs/dev.nix { inherit devo; }) dev dev-stop;

      # https://search.nixos.org/packages
      commonPackages = with pkgs; [
        # keep-sorted start
        babashka
        bottom
        chrome-devtools
        claude-app-server
        cli-proxy-api-management-center
        clj-kondo
        clojure-mcp-light
        coreutils
        dev
        dev-stop
        devenv
        diffutils
        dig
        duckdb
        eask-cli
        ffmpeg
        file
        ghostscript
        ghq
        ghq-sync
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
        portless
        postgresql
        rar
        rlwrap
        sqldef
        sqlite
        ssm-session-manager-plugin
        symphony
        tig
        tokei
        tree
        unixtools.watch
        unzip
        wrangler
        zip
        zlib
        # keep-sorted end
      ];

      linuxPackages = with pkgs; [
        # keep-sorted start
        (mpv.override { yt-dlp = pkgs.yt-dlp.override { javascriptSupport = false; }; })
        binutils
        burpsuite
        chromium
        dbeaver-bin
        discord
        firefox
        gimp
        gnome-system-monitor
        google-chrome
        googleearth-pro
        gparted
        lightpanda
        logseq
        microsandbox
        ollama
        pciutils
        qpdfview
        slack
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
        inputs.gitm.packages.${system}.default
        inputs.keg.packages.${system}.default
        inputs.pype.packages.${system}.default
        inputs.rust-llm-quota.packages.${system}.default
        devo
        pkgs.nodejs_24 # vibe-kanban requires npx
        pkgs.pnpm_10
      ]
      ++ (
        if pkgs.stdenv.isDarwin then
          [ ]
        else
          [
            claude-desktop-with-fhs
          ]
      )
      ++ (with inputs.llm-agents.packages.${system}; [
        # keep-sorted start
        agent-browser
        agent-deck
        aperant
        catnip
        ck
        claude-agent-acp
        codex-acp
        copilot-language-server
        # eca
        # gastown
        grok
        happy-coder
        # TODO: https://github.com/Dicklesworthstone/mcp_agent_mail
        # TODO: https://github.com/steveyegge/efrit
        vibe-kanban
        workmux
        # keep-sorted end
      ]);

    in
    commonPackages
    ++ (if pkgs.stdenv.isDarwin then macPackages else linuxPackages)
    ++ languageServers
    ++ inputPackages
    ++ shogiPackages;
}
