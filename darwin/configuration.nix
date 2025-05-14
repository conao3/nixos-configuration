{ pkgs, ... }:

{
  nix = {
    optimise.automatic = true;
    settings = {
      experimental-features = "nix-command flakes";
      max-jobs = 8;
    };
  };

  system = {
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
    pam.services.sudo_local.touchIdAuth = true;
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # cleanup = "uninstall";  # clojure/mkcert issue
    };
    casks = [
      "1password"
      "altair-graphql-client"
      "aquaskk"
      "asana"
      "claude"
      "corretto@11"
      "coteditor"
      "dbeaver-community"
      "docker"
      "figma"
      "firefox"
      "gimp"
      "google-japanese-ime"
      "jetbrains-toolbox"
      "karabiner-elements"
      "multipass"
      "session-manager-plugin"
      "slack"
      "thunderbird"
      "utm"
      "visual-studio-code"
      "vivaldi"
      "vmware-fusion"
      "xmind"
    ];
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-lgc-plus
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    noto-fonts-emoji-blob-bin
    noto-fonts-monochrome-emoji
    hackgen-font
    hackgen-nf-font
    # nerdfonts
    emacs-all-the-icons-fonts
    font-awesome
    font-awesome_5
  ];
}
