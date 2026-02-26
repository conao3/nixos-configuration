{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dashboard;
  generator = pkgs.callPackage ../pkgs/dashboard-generator.nix { };
  frontend = pkgs.callPackage ../pkgs/dashboard-frontend.nix { };
  detailApiScript = pkgs.writeText "dashboard-detail-api.py" (builtins.readFile ./dashboard-detail-api.py);
in
{
  options.services.dashboard = {
    enable = lib.mkEnableOption "localhost-only dashboard for listening ports";

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

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/dashboard";
      description = "Directory where generated JSON data is written.";
    };

    updateInterval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "Systemd timer interval for regenerating the page.";
    };

    detailApiPort = lib.mkOption {
      type = lib.types.port;
      default = 9501;
      description = "Port on localhost for on-demand process detail API.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts."dashboard.local" = {
        listen = [
          {
            addr = cfg.bindAddress;
            port = cfg.port;
          }
        ];
        root = frontend;
        locations."/" = {
          tryFiles = "$uri /index.html";
        };
        locations."/data/" = {
          alias = "${cfg.dataDir}/";
          extraConfig = ''
            add_header Cache-Control "no-store";
          '';
        };
        locations."/api/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.detailApiPort}/";
          extraConfig = ''
            proxy_http_version 1.1;
            proxy_set_header Host $host;
          '';
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    systemd.services.dashboard = {
      description = "Generate dashboard JSON";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        set -euo pipefail
        ${generator}/bin/dashboard-generator ${cfg.dataDir}/ports.json
      '';
    };

    systemd.timers.dashboard = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.updateInterval;
        Unit = "dashboard.service";
      };
    };

    systemd.services.dashboard-detail-api = {
      description = "Dashboard on-demand process detail API";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${detailApiScript}";
        Restart = "always";
        RestartSec = "2";
        Environment = [
          "DASHBOARD_API_HOST=127.0.0.1"
          "DASHBOARD_API_PORT=${toString cfg.detailApiPort}"
        ];
      };
    };
  };
}
