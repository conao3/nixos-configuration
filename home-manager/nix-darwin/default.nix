{ pkgs, ... }:

{
  nix = {
    optimise.automatic = true;
    settings = {
      experimental-features = "nix-command flakes";
      max-jobs = 8;
    };
  };

  services.nix-daemon.enable = true;

  system = {
    stateVersion = 5;
    defaults = {
      NSGlobalDomain.AppleShowAllExtensions = true;
      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
      };
      dock = {
        autohide = true;
        show-recents = false;
        orientation = "left";
      };
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
    };
    casks = [
      "1password"
      "altair-graphql-client"
      "asana"
      "corretto@11"
      "coteditor"
      "dbeaver-community"
      "docker"
      "figma"
      "firefox"
      "font-hackgen"
      "gimp"
      "google-japanese-ime"
      "jetbrains-toolbox"
      "karabiner-elements"
      "ngrok"
      "slack"
      "thunderbird"
      "utm"
      "visual-studio-code"
      "vmware-fusion"
      "xmind"
    ];
  };
}
