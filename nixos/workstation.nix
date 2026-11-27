{
  lib,
  pkgs,
  ...
}:
let
  cliProxyApiManagementCenterPackage =
    pkgs.callPackage ../pkgs/cli-proxy-api-management-center.nix
      { };
in
{
  # Chrome / Chromium 系ブラウザへの拡張 force-install ポリシー
  # (/etc/opt/chrome/policies 等に配置され、ブラウザ再起動で反映される)
  programs.chromium = {
    enable = true;
    extensions = [
      # drawio-mcp-extension: drawio-mcp-server (ws://localhost:3333) と稼働中の
      # draw.io エディタタブを仲介する
      "okdbbjbbccdhhfaefmcmekalmmdjjide"
    ];
  };

  systemd.user.services = {
    agent-memory-sync = {
      description = "Sync ~/.agents and push encrypted agent-memory-data";
      serviceConfig = {
        Type = "oneshot";
        Environment = "GIT_SSH_COMMAND=${pkgs.openssh}/bin/ssh";
        ExecStart = "${pkgs.writeShellScript "agent-memory-sync" ''
          set -euxo pipefail -o posix
          repo_dir="$HOME/ghq/github.com/conao3/agent-memory-data"
          cd "$repo_dir"

          current_branch=$(${pkgs.git}/bin/git rev-parse --abbrev-ref HEAD)
          if [ "$current_branch" != "master" ]; then
            ${pkgs.git}/bin/git switch master
          fi
          ${pkgs.git}/bin/git fetch origin master
          ${pkgs.git}/bin/git rebase origin/master

          ${pkgs.nix}/bin/nix run .#sync-push
          ${pkgs.nix}/bin/nix run .#sync-pull

          ${pkgs.git}/bin/git add data
          if ${pkgs.git}/bin/git diff --cached --quiet; then
            exit 0
          fi

          ${pkgs.coreutils}/bin/env PATH=${lib.makeBinPath [ pkgs.git ]} \
            ${pkgs.gitleaks}/bin/gitleaks git --staged --redact --no-banner
          ${pkgs.git}/bin/git commit --no-verify -m "chore(memory): hourly sync"
          ${pkgs.git}/bin/git push origin master
        ''}";
      };
    };

    cli-proxy-api-management-center = {
      description = "CLIProxyAPI Management Center";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${cliProxyApiManagementCenterPackage}/bin/cli-proxy-api-management-center";
        Restart = "always";
        RestartSec = "5";
        Environment = [
          "CLIPROXY_MGMT_CENTER_HOST=127.0.0.1"
          "CLIPROXY_MGMT_CENTER_PORT=8788"
        ];
      };
    };
  };

  # systemd.user.timers.agent-memory-sync = {
  #   wantedBy = [ "timers.target" ];
  #   timerConfig = {
  #     OnBootSec = "3min";
  #     OnUnitActiveSec = "1h";
  #     Persistent = true;
  #     RandomizedDelaySec = "5min";
  #   };
  # };
}
