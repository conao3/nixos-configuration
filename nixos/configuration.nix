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
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "@wheel" ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    grub.configurationLimit = 42;
  };

  networking = {
    hostName = "conao-nixos-helios";
    firewall.enable = true;
    networkmanager.enable = true;
  };

  time.timeZone = "Asia/Tokyo";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "ja_JP.UTF-8";
      LC_IDENTIFICATION = "ja_JP.UTF-8";
      LC_MEASUREMENT = "ja_JP.UTF-8";
      LC_MONETARY = "ja_JP.UTF-8";
      LC_NAME = "ja_JP.UTF-8";
      LC_NUMERIC = "ja_JP.UTF-8";
      LC_PAPER = "ja_JP.UTF-8";
      LC_TELEPHONE = "ja_JP.UTF-8";
      LC_TIME = "ja_JP.UTF-8";
    };
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

  boot.extraModprobeConfig = ''
    options hid_apple fnmode=2
  '';

  services = {
    displayManager.defaultSession = "xfce";
    # displayManager.defaultSession = "none+i3";
    spice-vdagentd.enable = true;
    blueman.enable = true;
    gnome.gnome-keyring.enable = true;
    displayManager = {
      autoLogin = {
        enable = true;
        user = "conao";
      };
    };
    xserver = {
      enable = true;
      xkb = {
        options = "ctrl:nocaps,altwin:swap_alt_win";
      };
      displayManager = {
        sessionCommands = ''
          ${pkgs.xorg.xset}/bin/xset r rate 200 50
        '';
      };
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
    openssh = {
      enable = true;
      settings = {
        X11Forwarding = true;
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
      openFirewall = true;
    };
  };

  users.users.conao = {
    isNormalUser = true;
    initialHashedPassword = "$y$j9T$uV54QRfWPePTdlGa6.3Bg0$mUm0g4FAdNT6OLzHkjllngfKWfd0ux0aBfENE6gCfK/";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "docker" ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git # required by home-manager
  ];

  programs = {
    fish.enable = true;
    zsh.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      noto-fonts-emoji-blob-bin
      hackgen-font
      hackgen-nf-font
    ];
    fontconfig = {
      defaultFonts = {
        serif = ["Noto Serif CJK JP" "Noto Color Emoji"];
        sansSerif = ["Noto Sans CJK JP" "Noto Color Emoji"];
        monospace = ["JetBrainsMono Nerd Font" "Noto Color Emoji"];
        emoji = ["Noto Color Emoji"];
      };
    };
  };

  virtualisation = {
    docker.enable = true;
    vmVariant = {
      virtualisation = {
        memorySize = 10240;
        cores = 4;
      };
    };
  };
}
