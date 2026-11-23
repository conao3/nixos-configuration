{ config, ... }:
let
  home = config.home.homeDirectory;
in
{
  systemd.user.services.sanimmerse-agent = {
    Unit = {
      Description = "sanimmerse agent (127.0.0.1:7600)";
      PartOf = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "network-online.target"
      ];
    };
    Service = {
      WorkingDirectory = "${home}/ghq/github.com/sancode-org/sanimmerse";
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=${home}/.Xauthority"
        "SANIMMERSE_ANKIWEB_USER=conao3@gmail.com"
        "SANIMMERSE_ANKIWEB_PASSWORD_FILE=${home}/.config/anki-sync/ankiweb.pass"
        "SANIMMERSE_TOKEN_FILE=${home}/.config/sanimmerse/token"
        "SANIMMERSE_CLOUD_URL=https://sanimmerse.sancode.dev"
        "SANIMMERSE_CLOUD_TOKEN_FILE=${home}/.config/sanimmerse/cloud-token"
      ];
      ExecStart = "/run/current-system/sw/bin/nix run .";
      Restart = "always";
      RestartSec = 30;
      TimeoutStartSec = 900;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
