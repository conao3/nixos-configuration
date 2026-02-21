{
  pkgs,
  inputs,
  ...
}:

{
  system.stateVersion = "24.11";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.conao = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFC6/Nfy2RrRM4oRtUw8U0JHq5CyDPXxpGGgBsnWku48 conao@nixos"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  services = {
    xserver = {
      enable = true;
      desktopManager.xfce = {
        enable = true;
        enableScreensaver = false;
      };
    };
    displayManager = {
      defaultSession = "xfce";
      autoLogin = {
        enable = true;
        user = "conao";
      };
    };
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };
  };

  virtualisation.vmVariant.virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 2222;
      guest.port = 22;
    }
  ];
}
