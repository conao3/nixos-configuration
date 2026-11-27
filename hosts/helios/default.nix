{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cagentBin = "/home/conao/ghq/github.com/conao3/rust-cagent/target/debug/cagent";
in
{
  imports = [
    ./hardware-configuration.nix
    ./board-history.nix
    ./llm-usage.nix
    ./sunshine.nix
    ./sysmon.nix
  ];

  systemd.slices."user".sliceConfig.MemoryHigh = "38G";

  networking.hostName = "conao-nixos-helios";

  sops = {
    templates."cagent-config" = {
      owner = "conao";
      path = "/home/conao/.config/cagent/config.toml";
      content = ''
        claude_command = "claude.yui"
        claude_config_dir = "/home/conao/.agents/.claude.yui"

        [telegram]
        token = "${config.sops.placeholder."matterbridge-telegram-token"}"
        working_dir = "/home/conao/ghq"
      '';
    };
    secrets.matterbridge-telegram-token = { };
  };

  networking.hosts."160.79.104.10" = [
    "api.anthropic.com"
    "platform.claude.com"
  ];

  networking.getaddrinfo.precedence = {
    "::1/128" = 50;
    "::/0" = 40;
    "2002::/16" = 30;
    "::/96" = 20;
    "::ffff:0:0/96" = 100;
  };

  # cagent: disabled due to high memory usage (437M+), enable when needed
  # systemd.user.services.cagent = {
  #   description = "cagent server";
  #   after = [ "network.target" ];
  #   wantedBy = [ "default.target" ];
  #   path = [ "/etc/profiles/per-user/conao" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     WorkingDirectory = "/home/conao/ghq";
  #     ExecStart = "${cagentBin} server start-server";
  #     Restart = "always";
  #     RestartSec = "5";
  #   };
  # };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 5900 ];

  systemd.services.x11vnc = {
    description = "x11vnc VNC server for physical display";
    after = [ "display-manager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.x11vnc}/bin/x11vnc"
        "-display :0"
        "-auth /home/conao/.Xauthority"
        "-forever"
        "-shared"
        "-nopw"
        "-rfbport 5900"
        "-wait 5"
        "-defer 5"
      ];
      Restart = "always";
      RestartSec = 5;
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];

  systemd.user.services = {
    vm-agent-tunnel = {
      description = "SSH tunnel to agent-vm";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.autossh}/bin/autossh"
          "-M 0"
          "-N"
          "-p 2222"
          "-o ServerAliveInterval=10"
          "-o ServerAliveCountMax=3"
          "-o ExitOnForwardFailure=yes"
          "-o StrictHostKeyChecking=no"
          "-L 9119:127.0.0.1:9119"
          "-L 8787:127.0.0.1:8787"
          "-L 9120:127.0.0.1:3000"
          "-L 18789:127.0.0.1:18789"
          "-L 18792:127.0.0.1:18792"
          "-L 18701:127.0.0.1:18701"
          "conao@localhost"
        ];
        Restart = "always";
        RestartSec = "5";
        Environment = "AUTOSSH_GATETIME=0";
      };
    };
  };
}
