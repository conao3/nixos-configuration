{ pkgs, ... }:

{
  # System configurations
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

  # Enable Touch ID for sudo
  security = {
    pam.services.sudo_local.touchIdAuth = true;
  };

  # Homebrew packages and applications
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # cleanup = "uninstall";  # clojure/mkcert issue
    };
    casks = [
      # Development
      "corretto@11"
      "docker"
      "dbeaver-community"
      "jetbrains-toolbox"
      "visual-studio-code"

      # Browsers
      "firefox"
      "vivaldi"

      # Productivity
      "1password"
      "altair-graphql-client"
      "session-manager-plugin"
      "slack"
      "thunderbird"
      "xmind"
      "asana"
      "multipass"

      # Input methods and customization
      "aquaskk"
      "google-japanese-ime"
      "karabiner-elements"

      # Media/Graphics
      "coteditor"
      "figma"
      "gimp"

      # Virtualization
      "utm"
      "vmware-fusion"

      # AI tools
      "claude"
    ];
  };

  # System fonts
  fonts.packages = with pkgs; [
    # Noto font family
    noto-fonts
    noto-fonts-lgc-plus
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    noto-fonts-emoji-blob-bin
    noto-fonts-monochrome-emoji

    # Developer fonts
    hackgen-font
    hackgen-nf-font
    # nerdfonts

    # Icon fonts
    emacs-all-the-icons-fonts
    font-awesome
    font-awesome_5
  ];
}
