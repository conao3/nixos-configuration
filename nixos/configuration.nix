{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "24.11";

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-order-than 7d";
    };
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "@wheel"];
    };
  };

  nixpkgs.config.allowUnfree = true;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    firewall.enable = true;
    hostName = "conao-nixos-perses";
  };

  time.timeZone = "Asia/Tokyo";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        addons = with pkgs; [
          fcitx5-skk
        ];
      };
    };
  };

  services = {
    # displayManager.defaultSession = "xfce";
    displayManager.defaultSession = "none+i3";
    xserver = {
      enable = true;
      desktopManager = {
        xterm.enable = false;
        xfce = {
          enable = true;
          enableScreensaver = false;
        };
      };
      windowManager = {
        i3 = {
          enable = true;
          extraPackages = with pkgs; [
            dmenu
            i3status
            i3lock
            i3blocks
          ];
        };
      };
    };
    libinput = {
      enable = true;
      touchpad = {
        disableWhileTyping = true;
      };
    };
    openssh.enable = true;
    spice-vdagentd.enable = true;
  };

  users.users.conao = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "docker" ];
  };

  environment.systemPackages = with pkgs; [
    git                         # required by home-manager
  ];

  programs = {
    fish.enable = true;
    zsh.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  virtualisation = {
    docker.enable = true;
  };
}
