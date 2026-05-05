{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cagentBin = "/home/conao/ghq/github.com/conao3/rust-cagent/target/debug/cagent";
  codingAgentJobs = {
    # systemd timerConfig.OnCalendar format, not cron syntax.
    # Examples:
    # - "*:0/5" = every 5 minutes (:00, :05, :10, ...)
    # - "*:0/30" = every 30 minutes starting at :00 (:00, :30)
    # - "*:10/30" = every 30 minutes starting at :10 (:10, :40)
    # - "hourly" = every hour
    # - "*-*-* 03:00:00" = every day at 03:00
    agent-heartbeat = {
      enabled = false;
      schedule = "*:0/30";
      target = "electrobunmacs-orchestrator:0.0";
      input = "Orchestrator: heartbeat";
      description = "Send heartbeat to Codex pane";
      guard = "codex";
    };
    qa-heartbeat = {
      enabled = false;
      schedule = "*:10/30";
      target = "electrobunmacs-qa:0.0";
      input = "QA: heartbeat";
      description = "Send heartbeat to QA Codex pane";
      guard = "codex";
    };
    qa-claude-heartbeat = {
      enabled = false;
      schedule = "*:20/30";
      target = "electrobunmacs-qa-claude:0.0";
      input = "QA: heartbeat";
      description = "Send heartbeat to QA Claude pane";
      guard = "claude";
    };
  };
  mkCodingAgentService =
    name: job:
    let
      escapedInput = lib.escapeShellArg job.input;
      escapedTarget = lib.escapeShellArg job.target;
      escapedGuard = lib.escapeShellArg job.guard;
      jobDescription = job.description or "Send input to tmux pane";
    in
    {
      description = jobDescription;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "coding-agent-${name}" ''
          set -euo pipefail

          target=${escapedTarget}
          input=${escapedInput}
          current_command=$(${pkgs.tmux}/bin/tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null || true)
          if [ -z "$current_command" ]; then
            exit 0
          fi

          if ! ${pkgs.gnugrep}/bin/grep -Fq -- ${escapedGuard} <<EOF
$current_command
EOF
          then
            exit 0
          fi

          for ((i = 0; i < ''${#input}; i++)); do
            ch="''${input:i:1}"
            case "$ch" in
              ' ')
                ${pkgs.tmux}/bin/tmux send-keys -t "$target" Space
                ;;
              *)
                ${pkgs.tmux}/bin/tmux send-keys -t "$target" "$ch"
                ;;
            esac
            sleep 0.02
          done
          ${pkgs.tmux}/bin/tmux send-keys -t "$target" Enter
        ''}";
      };
    };
  enabledCodingAgentJobs = lib.filterAttrs (_: job: job.enabled) codingAgentJobs;
  codingAgentServices = lib.mapAttrs' (
    name: job: lib.nameValuePair name (mkCodingAgentService name job)
  ) enabledCodingAgentJobs;
  codingAgentTimers = lib.mapAttrs' (
    name: job:
    lib.nameValuePair name {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = job.schedule;
        Persistent = true;
      };
    }
  ) enabledCodingAgentJobs;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "conao-nixos-helios";
  networking.firewall.trustedInterfaces = [
    "docker0"
    "br-+"
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/conao/.config/sops/age/keys.txt";
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
    templates."helios-env" = {
      owner = "conao";
      content = ''
        export LINEAR_API_KEY=${config.sops.placeholder."linear-api-key"}
        export DEVIN_API_KEY=${config.sops.placeholder."devin-api-key"}
      '';
    };
    templates."ollama-tunnel-script" = {
      owner = "conao";
      mode = "0500";
      content = ''
        #!/bin/sh
        exec ${config.sops.placeholder."ollama-tunnel-exec"}
      '';
    };
    templates."gitea-mirror-env" = {
      owner = "conao";
      content = ''
        GITEA_TOKEN=${config.sops.placeholder."gitea-api-token"}
      '';
    };
    secrets.gitea-api-token = { };
    secrets.matterbridge-telegram-token = { };
    secrets.linear-api-key = { };
    secrets.devin-api-key = { };
    secrets.ollama-tunnel-exec = { };
    secrets.dev-ca-key = {
      owner = "conao";
      path = "/home/conao/.local/share/dev-ca/rootCA-key.pem";
    };
  };

  programs.zsh.interactiveShellInit = ''
    [ -f ${config.sops.templates."helios-env".path} ] && source ${
      config.sops.templates."helios-env".path
    }
  '';

  # cagent: disabled due to high memory usage (437M+), enable when needed
  # systemd.user.services.cagent = {
  #   description = "cagent server";
  #   after = [ "network.target" ];
  #   wantedBy = [ "default.target" ];
  #   path = [ "/etc/profiles/per-user/conao" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     WorkingDirectory = "/home/conao/ghq";
  #     ExecStart = "${cagentBin} server";
  #     Restart = "always";
  #     RestartSec = "5";
  #   };
  # };

  systemd.services.ollama-tunnel = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
    serviceConfig = {
      Type = "simple";
      User = "conao";
      WorkingDirectory = "/home/conao";
      ExecStart = "${pkgs.bash}/bin/bash ${config.sops.templates."ollama-tunnel-script".path}";
      Restart = "always";
      RestartSec = 3;
    };
  };

  security.pki.certificateFiles = [ ../../secrets/dev-rootCA.pem ];

  zramSwap.enable = true;

  swapDevices = [
    {
      device = "/swapfile";
      size = 128 * 1024;
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

    memory-alert = {
      description = "Memory usage alert";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "memory-alert" ''
          set -euxo pipefail -o posix
          usage=$(${pkgs.gawk}/bin/awk '/MemTotal/ {total=$2} /MemAvailable/ {available=$2} END {printf "%d", (total - available) * 100 / total}' /proc/meminfo)
          if [ "''${usage}" -ge 80 ]; then
            ${pkgs.libnotify}/bin/notify-send -u critical "Memory Alert" "Memory usage: ''${usage}%"
          fi
        ''}";
      };
    };

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
  } // codingAgentServices;

  systemd.user.timers = {
    memory-alert = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
      };
    };
  } // codingAgentTimers;

  # systemd.user.timers.agent-memory-sync = {
  #   wantedBy = [ "timers.target" ];
  #   timerConfig = {
  #     OnBootSec = "3min";
  #     OnUnitActiveSec = "1h";
  #     Persistent = true;
  #     RandomizedDelaySec = "5min";
  #   };
  # };

  systemd.services.gitea-mirror = {
    description = "Mirror local git repositories to Gitea";
    after = [
      "network.target"
      "gitea.service"
    ];
    wants = [ "gitea.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "conao";
      TimeoutStartSec = "30min";
      Environment = "GIT_SSH_COMMAND=${pkgs.openssh}/bin/ssh";
      ExecStart = "${pkgs.writeShellScript "gitea-mirror" ''
        set -euxo pipefail -o posix
        source ${config.sops.templates."gitea-mirror-env".path}

        for repo_dir in $(${pkgs.findutils}/bin/find "$HOME/ghq/github.com" -maxdepth 2 -mindepth 2 -type d | ${pkgs.coreutils}/bin/sort); do
          rel_path=''${repo_dir#$HOME/ghq/github.com/}
          org=$(${pkgs.coreutils}/bin/dirname "$rel_path")
          repo=$(${pkgs.coreutils}/bin/basename "$rel_path")

          if ! ${pkgs.git}/bin/git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
            continue
          fi

          status=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $GITEA_TOKEN" \
            "http://localhost:9404/api/v1/repos/$org/$repo")

          if [ "$status" = "404" ]; then
            if [ "$org" = "conao3" ]; then
              ${pkgs.curl}/bin/curl -s -X POST \
                -H "Authorization: token $GITEA_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"name\":\"$repo\",\"private\":false}" \
                "http://localhost:9404/api/v1/user/repos"
            else
              ${pkgs.curl}/bin/curl -s -X POST \
                -H "Authorization: token $GITEA_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"username\":\"$org\",\"visibility\":\"public\"}" \
                "http://localhost:9404/api/v1/orgs" || true

              ${pkgs.curl}/bin/curl -s -X POST \
                -H "Authorization: token $GITEA_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"name\":\"$repo\",\"private\":false}" \
                "http://localhost:9404/api/v1/org/$org/repos"
            fi
          fi

          if ! ${pkgs.git}/bin/git -C "$repo_dir" remote get-url gitea >/dev/null 2>&1; then
            ${pkgs.git}/bin/git -C "$repo_dir" remote add gitea "gitea@localhost:$org/$repo.git"
          fi

          ${pkgs.git}/bin/git -C "$repo_dir" push gitea --all || true
          ${pkgs.git}/bin/git -C "$repo_dir" push gitea --tags || true
        done
      ''}";
    };
  };

  systemd.timers.gitea-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "6h";
      Persistent = true;
    };
  };
}
