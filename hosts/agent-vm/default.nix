{
  pkgs,
  inputs,
  ...
}:

{
  system.stateVersion = "24.11";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    require-sigs = false;
    trusted-users = [
      "root"
      "conao"
    ];
  };

  boot.loader.grub = {
    enable = true;
    device = "nodev";
  };

  users.users.conao = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFC6/Nfy2RrRM4oRtUw8U0JHq5CyDPXxpGGgBsnWku48 conao@nixos"
    ];
  };

  programs.zsh.enable = true;

  security.sudo.wheelNeedsPassword = false;

  services = {
    xserver = {
      enable = true;
      desktopManager.xfce = {
        enable = true;
        enableScreensaver = false;
      };
      displayManager.sessionCommands = ''
        (
          prev_mode=""
          while true; do
            mode=$(head -1 /sys/class/drm/card0-Virtual-1/modes 2>/dev/null)
            if [ -n "$mode" ] && [ "$mode" != "$prev_mode" ]; then
              ${pkgs.xorg.xrandr}/bin/xrandr --output Virtual-1 --mode "$mode"
              prev_mode="$mode"
            fi
            sleep 1
          done
        ) &
      '';
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

  virtualisation.vmVariant.virtualisation = {
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    sharedDirectories =
      let
        hostRepo = name: {
          source = "/home/conao/dev/repos/${name}";
          target = "/home/conao/dev/host-repos/${name}";
        };
      in
      {
        nixos-configuration = hostRepo "nixos-configuration";
        sops-age = {
          source = "/home/conao/.config/sops/age";
          target = "/home/conao/.config/sops/age";
        };
      };
    qemu.options = [
      "-vga virtio"
      "-display gtk,zoom-to-fit=off"
    ];
  };
}
