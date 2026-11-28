{
  pkgs,
  lib,
  system,
  inputs,
  ...
}:
{
  # https://search.nixos.org/packages?channel=24.11
  home.packages =
    let
      agent-friction = inputs.agent-friction.packages.${system}.default;
      brave = pkgs.callPackage ../pkgs/brave { };
      cgpu = pkgs.callPackage ../pkgs/cgpu { };
      claude-desktop-with-fhs = pkgs.callPackage ../pkgs/claude-desktop-fhs.nix {
        src = inputs.claude-desktop;
      };
      chrome-devtools = inputs.chrome-devtools.packages.${system}.default;
      cli-proxy-api-management-center = pkgs.callPackage ../pkgs/cli-proxy-api-management-center.nix { };
      comma = pkgs.callPackage ../pkgs/comma.nix {
        inherit (inputs.nix-index-database.packages.${system}) comma-with-db;
      };
      devin-cli = pkgs.callPackage ../pkgs/yolo-flag.nix { } {
        package = pkgs.callPackage ../pkgs/devin-cli.nix { };
        flags = [
          "--permission-mode"
          "dangerous"
          "--respect-workspace-trust"
          "false"
        ];
      };
      cosense-cli = pkgs.callPackage ../pkgs/cosense-cli.nix { src = inputs.cosense-cli; };
      document-packet = inputs.document-packet.packages.${system}.default;
      ghq-sync = pkgs.callPackage ../pkgs/ghq-sync.nix { };
      idea-routine = inputs.idea-routine.packages.${system}.default;
      lightpanda = pkgs.callPackage ../pkgs/lightpanda.nix { };
      mo = pkgs.callPackage ../pkgs/mo.nix { };
      musewire = inputs.musewire.packages.${system}.default;
      outbound-manifest = inputs.outbound-manifest.packages.${system}.default;
      portless = pkgs.callPackage ../pkgs/portless.nix { };
      rec-audio = pkgs.callPackage ../pkgs/rec-audio.nix { };
      speak = pkgs.callPackage ../pkgs/speak.nix { };
      texassolver = pkgs.callPackage ../pkgs/texassolver.nix { };
      voice-type = pkgs.callPackage ../pkgs/voice-type.nix { };
      devo = pkgs.rustPlatform.buildRustPackage {
        pname = "devo";
        version = "0.1.0";
        src = inputs.devo;
        cargoLock.lockFile = inputs.devo + "/Cargo.lock";
      };
      wrangler = pkgs.writeShellScriptBin "wrangler" ''
        exec ${pkgs.nodejs_24}/bin/npx --yes wrangler@4.62.0 "$@"
      '';
      inherit
        (pkgs.callPackage ../pkgs/dev.nix {
          inherit devo;
          tmux =
            if pkgs.stdenv.hostPlatform.isLinux then
              pkgs.callPackage ../pkgs/tmux-with-server.nix { }
            else
              pkgs.tmux;
        })
        dev
        dev-stop
        ;

      # https://search.nixos.org/packages
      commonPackages = with pkgs; [
        # keep-sorted start
        agent-friction
        babashka
        bottom
        cgpu
        chrome-devtools
        cli-proxy-api-management-center
        clj-kondo
        clojure-mcp-light
        comma
        coreutils
        cosense-cli
        dev
        dev-stop
        devenv
        devin-cli
        diffutils
        dig
        document-packet
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
        groff
        idea-routine
        imagemagick
        inetutils
        libgccjit
        mo
        modal
        musewire
        neil
        ngrok
        nkf
        obsidian
        outbound-manifest
        parallel
        perl
        portless
        postgresql
        python3
        rar
        rlwrap
        ruby
        sqldef
        sqlite
        ssm-session-manager-plugin
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
        anki
        binutils
        brave
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
        libreoffice
        lightpanda
        livecaptions
        logseq
        microsandbox
        moonlight-qt
        ollama
        pavucontrol
        pciutils
        qdirstat
        qpdfview
        rec-audio
        seahorse
        slack
        speak
        steam-run
        telegram-desktop
        texassolver
        tigervnc
        vlc
        voice-type
        xclip
        xsel
        # keep-sorted end
      ];

      macPackages = with pkgs; [
        # keep-sorted start
        gnumake
        pngpaste
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
        (inputs.llm-agents.packages.${system}.codex-acp.override {
          codex = pkgs.callPackage ../pkgs/codex.nix {
            fallbackPackage = inputs.llm-agents.packages.${system}.codex;
          };
        })
        (lib.lowPrio inputs.llm-agents.packages.${system}.bb-app)
        inputs.awsr.packages.${system}.default
        inputs.gitm.packages.${system}.default
        inputs.keg.packages.${system}.default
        inputs.pype.packages.${system}.default
        inputs.rust-llm-quota.packages.${system}.default
        devo
        pkgs.nodejs_24
        pkgs.pnpm_10
      ]
      ++ (
        if pkgs.stdenv.hostPlatform.isDarwin then
          [ ]
        else
          [
            claude-desktop-with-fhs
          ]
      )
      ++ (with inputs.llm-agents.packages.${system}; [
        # keep-sorted start
        agent-deck
        aperant
        ck
        claude-agent-acp
        copilot-language-server
        # eca
        # gastown
        grok
        happy-coder
        # TODO: https://github.com/Dicklesworthstone/mcp_agent_mail
        # TODO: https://github.com/steveyegge/efrit
        workmux
        # keep-sorted end
      ]);

    in
    commonPackages
    ++ (if pkgs.stdenv.hostPlatform.isDarwin then macPackages else linuxPackages)
    ++ languageServers
    ++ inputPackages
    ++ shogiPackages;
}
