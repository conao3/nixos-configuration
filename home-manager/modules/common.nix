{
  username,
  ...
}:
{
  # Enable xsession only on Linux
  xsession = {
    enable = false; # Will be overridden on Linux
    initExtra = "xset r rate 200 50";
  };

  # Set common options for xfce keyboard shortcuts (for Linux)
  xfconf = {
    enable = false; # Will be overridden on Linux
    settings = {
      xfce4-keyboard-shortcuts = {
        # Keyboard shortcuts removed for brevity
      };

      keyboards = {
        "/Default/KeyRepeat/Delay" = 200;
        "/Default/KeyRepeat/Rate" = 50;
      };
    };
  };

  # Common home configuration
  home = {
    inherit username;
    stateVersion = "24.05";

    # Common session path settings
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.anyenv/bin"
      "$HOME/.elan/bin"
      "$HOME/.volta/bin"
      "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
    ];

    # Common locale settings
    language.base = "en_US.UTF-8";

    # Common file configurations
    file = {
      ".config" = {
        source = ../.config;
        recursive = true;
      };
      ".claude/CLAUDE.md" = {
        source = ../ext/CLAUDE.md;
      };
    };
  };
}
