{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  gh-lookout = inputs.gh-lookout.packages.${system}.default;
  configHome = config.xdg.configHome;
in
{
  programs.gh.extensions = [ gh-lookout ];

  xdg.configFile."gh-lookout/config.toml".text = ''
    [server]
    listen = "127.0.0.1:8767"

    [github]
    webhook_secret_file = "${configHome}/gh-lookout/webhook-secret"
    token_command = ["${pkgs.gh}/bin/gh", "auth", "token"]

    [[hook]]
    when = { event = "commit_completed" }
    run = ["${pkgs.bash}/bin/sh", "-c", "echo \"$(date -Is) $LOOKOUT_REPO $LOOKOUT_SHA_SHORT $LOOKOUT_CONCLUSION $LOOKOUT_URL\" >> \"$STATE_DIRECTORY/commits.log\""]
  '';

  systemd.user.services.gh-lookout = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "gh-lookout: GitHub workflow_run webhooks (Tailscale Funnel :10000)";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${gh-lookout}/bin/gh-lookout serve";
      StateDirectory = "gh-lookout";
      StateDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
