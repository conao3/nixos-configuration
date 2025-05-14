{
  pkgs,
  username,
  system,
  inputs,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  cljstyle = pkgs.callPackage ../pkgs/cljstyle.nix { };
in
{
  home.packages =
    let
      # Core system and development tools
      devTools = with pkgs; [
        # Programming languages
        cargo # Rust
        clojure
        deno
        nodejs
        python313

        # Shell utilities
        babashka
        rlwrap

        # Build tools
        binutils
        coreutils
        diffutils
        gnumake
        parallel

        # System tools
        dig
        inetutils

        # Version control
        ghq
        git-secrets
        tig

        # Package managers
        eask-cli
        pdm
        pipx
        pnpm
        poetry
        volta

        # Development tools
        devenv
        libgccjit
        mkcert
        sqldef
        tailscale
        tokei

        # Databases
        minio
        postgresql
        sqlite

        # Media processing
        ffmpeg
        ghostscript
        imagemagick
        mpv

        # Programming languages tools
        clj-kondo
        gprolog
        sbcl
        nkf

        # Archiving and compression
        unzip
        zip
        zlib

        # Custom packages
        cljstyle
      ];

      # Unfree packages, currently commented out
      unfreePackages = with pkgs; [
        # claude-code
        # jetbrains.idea-ultimate
        # ngrok
        # rar
        # vlc
      ];

      # Platform-specific packages
      linuxSpecific = with pkgs; [
        burpsuite
        chromium
        dbeaver-bin
        firefox
        gnome-system-monitor
        gparted
        ollama
        pciutils
        qpdfview
        unixtools.watch
        xsel
      ];

      macSpecific = with pkgs; [
        # Add any mac-specific packages here
      ];

      # Language servers for editors
      languageServers = with pkgs; [
        clojure-lsp
        typescript-language-server
        # nodePackages.graphql-language-service-cli
      ];

      # Input packages that might need special handling
      inputPackages =
        [
          inputs.cljgen.packages.${system}.default
          inputs.nix-flake-clojure.packages.${system}.default
        ]
        ++ (
          if !isDarwin then
            [
              inputs.claude-desktop.packages.${system}.claude-desktop
            ]
          else
            [ ]
        );
    in
    devTools ++ (if isDarwin then macSpecific else linuxSpecific) ++ languageServers ++ inputPackages;
}
