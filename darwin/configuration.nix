{ pkgs, username, ... }:

{
  nix = {
    optimise.automatic = true;
    linux-builder.enable = true;
    settings = {
      experimental-features = "nix-command flakes";
      max-jobs = 8;
      extra-substituters = [
        "https://numtide.cachix.org"
        "https://claude-code.cachix.org"
      ];
      extra-trusted-public-keys = [
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  system = {
    primaryUser = username;
    stateVersion = 6;
    defaults = {
      NSGlobalDomain.AppleShowAllExtensions = true;
      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
      };
      dock = {
        autohide = true;
        show-recents = false;
      };
      trackpad = {
        Clicking = true;
        Dragging = true;
      };
    };
  };

  security = {
    pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # cleanup = "uninstall";  # clojure/mkcert issue
    };
    taps = [
      "manaflow-ai/cmux"
    ];
    casks = [
      # keep-sorted start
      "1password"
      "KeyCastr"
      "altair-graphql-client"
      "aquaskk"
      "asana"
      "claude"
      "cmux"
      "codex"
      "corretto@11"
      "coteditor"
      "dbeaver-community"
      "docker-desktop"
      "figma"
      "firefox"
      "gimp"
      "google-chrome@beta"
      "google-japanese-ime"
      "karabiner-elements"
      "obsidian"
      "ollama-app"
      "session-manager-plugin"
      "slack"
      "thunderbird"
      "visual-studio-code"
      "zed"
      # keep-sorted end
    ];
  };

  services.tailscale = {
    enable = true;
    overrideLocalDns = true;
  };

  fonts.packages = with pkgs; [
    # keep-sorted start
    emacs-all-the-icons-fonts
    font-awesome
    font-awesome_5
    hackgen-font
    hackgen-nf-font
    # nerdfonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    noto-fonts-emoji-blob-bin
    noto-fonts-lgc-plus
    noto-fonts-monochrome-emoji
    # keep-sorted end
  ];
}
