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
        ${pkgs.xorg.xset}/bin/xset -dpms
        ${pkgs.xorg.xset}/bin/xset s off
        ${pkgs.xorg.xset}/bin/xset s noblank
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

  systemd.tmpfiles.rules = [
    "d /home/conao/.config 0755 conao users -"
    "d /home/conao/.config/sops 0755 conao users -"
    "d /home/conao/.config/sops/age 0755 conao users -"
    "d /home/conao/dev 0755 conao users -"
    "d /home/conao/dev/host-repos 0755 conao users -"
    "d /home/conao/dev/host-repos/nixos-configuration 0755 conao users -"
  ];

  systemd.mounts = [
    {
      type = "9p";
      options = "trans=virtio,version=9p2000.L";
      what = "sops-age";
      where = "/home/conao/.config/sops/age";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
    }
    {
      type = "9p";
      options = "trans=virtio,version=9p2000.L";
      what = "nixos-configuration";
      where = "/home/conao/dev/host-repos/nixos-configuration";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
    }
  ];

  virtualisation.vmVariant.virtualisation = {
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    qemu.options = [
      "-vga virtio"
      "-display gtk,zoom-to-fit=off"
      "-virtfs local,path=/home/conao/.config/sops/age,security_model=none,mount_tag=sops-age"
      "-virtfs local,path=/home/conao/dev/repos/nixos-configuration,security_model=none,mount_tag=nixos-configuration"
    ];
  };
}
