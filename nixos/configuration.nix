{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./dashboard.nix
  ];

  system.stateVersion = "24.11";

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than +5";
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      substituters = [
        # keep-sorted start
        "https://cache.nixos.org/"
        "https://cache.numtide.com"
        "https://emacs-ci.cachix.org"
        "https://nix-community.cachix.org"
        # keep-sorted end
      ];
      trusted-public-keys = [
        # keep-sorted start
        "emacs-ci.cachix.org-1:B5FVOrxhXXrOL0S+tQ7USrhjMT5iOPH+QN9q0NItom4="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        # keep-sorted end
      ];
    };
  };

  nixpkgs = {
    config.allowUnfree = true;
  };

  networking = {
    firewall.enable = true;
    networkmanager.enable = true;
  };

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = true;
    };

    extraModprobeConfig = ''
      options hid_apple fnmode=2
    '';

    binfmt.emulatedSystems = [ "aarch64-linux" ];
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

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services = {
    # Keep the classic dbus daemon so `nixos-rebuild switch` does not hit the
    # dbus -> broker switch inhibitor during ordinary updates.
    dbus.implementation = "dbus";
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
        # options = "ctrl:nocaps,altwin:swap_alt_win";
      };
      displayManager = {
        # default: 173 100
        # 250 25
        sessionCommands = ''
          ${pkgs.xset}/bin/xset r rate 400 25
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
            # keep-sorted start
            dmenu
            i3blocks
            i3lock
            i3status
            # keep-sorted end
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
      openFirewall = false;
      listenAddresses = [
        { addr = "127.0.0.1"; }
        { addr = "::1"; }
      ];
    };
    tailscale = {
      enable = true;
      extraSetFlags = [ "--ssh" ];
    };
    # open-webui = {
    #   enable = true;
    #   port = 9402;
    #   # https://docs.openwebui.com/reference/env-configuration
    #   environment = {
    #     WEBUI_AUTH = "False";
    #     OLLAMA_API_BASE_URL = "http://127.0.0.1:9403";
    #   };
    # };
  };

  services.dashboard = {
    enable = true;
    port = 9400;
  };

  services.gitea = {
    enable = true;
    settings.server = {
      HTTP_PORT = 9404;
      ROOT_URL = "http://localhost:9404/";
    };
  };

  services.cgit."local" = {
    enable = true;
    nginx.virtualHost = "cgit.local";
    scanPath = "/home/conao/ghq";
    gitHttpBackend.checkExportOkFiles = false;
    settings = {
      remove-suffix = 1;
      enable-git-config = 1;
      root-title = "Local Repositories";
      section-from-path = 3;
    };
  };

  services.nginx.virtualHosts."cgit.local" = {
    listen = [
      {
        addr = "127.0.0.1";
        port = 9405;
      }
    ];
  };

  systemd.tmpfiles.rules = [
    "d /home/conao 0711 conao users -"
  ];

  users.users.conao = {
    isNormalUser = true;
    initialHashedPassword = "$y$j9T$uV54QRfWPePTdlGa6.3Bg0$mUm0g4FAdNT6OLzHkjllngfKWfd0ux0aBfENE6gCfK/";
    shell = pkgs.zsh;
    extraGroups = [
      # keep-sorted start
      "docker"
      "kvm"
      "libvirtd"
      "wheel"
      # keep-sorted end
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages =
    with pkgs;
    [
      git # required by home-manager
      # Keep the xfce4-panel notification plugin available even though the
      # xfce4-notifyd daemon itself is hidden by Home Manager in favor of dunst.
      xfce4-notifyd
    ];

  environment.xfce.excludePackages = with pkgs; [
    xfce4-notifyd
  ];

  programs = {
    zsh.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
  };

  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      # keep-sorted start
      hackgen-font
      hackgen-nf-font
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
      noto-fonts-emoji-blob-bin
      texlivePackages.haranoaji
      # keep-sorted end
    ];
    fontconfig = {
      defaultFonts = {
        serif = [
          "Noto Serif CJK JP"
          "Noto Color Emoji"
        ];
        sansSerif = [
          "Noto Sans CJK JP"
          "Noto Color Emoji"
        ];
        monospace = [
          "Hackgen Console NF"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true; # enable kvm
    vmVariant = {
      virtualisation = {
        memorySize = 10240;
        cores = 4;
      };
    };
  };
}
