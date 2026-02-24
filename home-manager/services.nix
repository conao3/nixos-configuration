{
  lib,
  pkgs,
  username,
  ...
}:
{
  services.emacs = {
    enable = true;
    defaultEditor = true;
  };

  systemd.user.services = lib.mkIf (!pkgs.stdenv.isDarwin) {
    beads-ui = {
      Unit = {
        Description = "Beads UI";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        WorkingDirectory = "/home/${username}/.openclaw/workspace";
        ExecStart = "${pkgs.pnpm}/bin/pnpm dlx beads-ui start --port 18701";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
