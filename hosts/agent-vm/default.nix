{
  pkgs,
  inputs,
  ...
}:

{
  system.stateVersion = "24.11";

  networking.hostName = "conao-nixos-agent";
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
    extraGroups = [
      "docker"
      "wheel"
    ];
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
        ${pkgs.xset}/bin/xset -dpms
        ${pkgs.xset}/bin/xset s off
        ${pkgs.xset}/bin/xset s noblank
        (
          prev_mode=""
          while true; do
            mode=$(head -1 /sys/class/drm/card0-Virtual-1/modes 2>/dev/null)
            if [ -n "$mode" ] && [ "$mode" != "$prev_mode" ]; then
              ${pkgs.xrandr}/bin/xrandr --output Virtual-1 --mode "$mode"
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

  systemd.services.grow-root-filesystem = {
    description = "Grow root filesystem to fill the VM disk";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.e2fsprogs}/bin/resize2fs /dev/disk/by-label/nixos";
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/conao/.config 0755 conao users -"
    "d /home/conao/.config/sops 0755 conao users -"
    "d /home/conao/.config/sops/age 0755 conao users -"
    "d /home/conao/.agents 0755 conao users -"
    "d /home/conao/ghq 0755 conao users -"
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
      what = "agents";
      where = "/home/conao/.agents";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
    }
    {
      type = "virtiofs";
      what = "dev-repos";
      where = "/home/conao/ghq";
      wantedBy = [ "multi-user.target" ];
    }
  ];

  virtualisation.vmVariant.virtualisation = {
    memorySize = 4096;
    diskSize = 100 * 1024;
    writableStoreUseTmpfs = false;
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    qemu.options = [
      "-vga virtio"
      "-display gtk,zoom-to-fit=on"
      "-virtfs local,path=/home/conao/.config/sops/age,security_model=none,mount_tag=sops-age"
      "-virtfs local,path=/home/conao/.agents,security_model=none,mount_tag=agents"
      "-chardev socket,id=char-dev-repos,path=/tmp/virtiofsd-dev-repos.sock"
      "-device vhost-user-fs-pci,chardev=char-dev-repos,tag=dev-repos"
    ];
  };

  services.tailscale.enable = true;

  virtualisation.docker.enable = true;
}
