{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ports-portal;
  generator = pkgs.callPackage ../pkgs/ports-portal-generator.nix { };
in
{
  options.services.ports-portal = {
    enable = lib.mkEnableOption "localhost-only portal for listening ports";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9500;
      description = "Port on 127.0.0.1 for serving the generated portal.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address for nginx to bind.";
    };

    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/www/ports";
      description = "Directory where generated HTML is written.";
    };

    updateInterval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "Systemd timer interval for regenerating the page.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts."ports.local" = {
        listen = [
          {
            addr = cfg.bindAddress;
            port = cfg.port;
          }
        ];
        root = cfg.outputDir;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.outputDir} 0755 root root -"
    ];

    systemd.services.ports-portal = {
      description = "Generate ports portal HTML";
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        set -euo pipefail
        ${generator}/bin/ports-portal-generator ${cfg.outputDir}/index.html
      '';
    };

    systemd.timers.ports-portal = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.updateInterval;
        Unit = "ports-portal.service";
      };
    };
  };
}
