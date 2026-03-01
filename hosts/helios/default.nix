{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  claudeBin = "${inputs.llm-agents.packages.${pkgs.system}.claude-code}/bin/claude";
  yuiConfigDir = "/home/conao/.agents/.claude.yui";
  claudeTelegramScript = pkgs.writeShellScript "claude-telegram" ''
    set -euxo pipefail -o posix

    MATTERBRIDGE_API="http://127.0.0.1:4242"
    export CLAUDE_CONFIG_DIR="${yuiConfigDir}"
    session_file=$(${pkgs.coreutils}/bin/mktemp /tmp/claude-session.XXXXXX)
    main_fifo=$(${pkgs.coreutils}/bin/mktemp -u /tmp/matterbridge-sse.XXXXXX)
    latest_msg_file=$(${pkgs.coreutils}/bin/mktemp /tmp/claude-latest-msg.XXXXXX)
    latest_seq_file=$(${pkgs.coreutils}/bin/mktemp /tmp/claude-latest-seq.XXXXXX)
    result_file=$(${pkgs.coreutils}/bin/mktemp /tmp/claude-result.XXXXXX)
    ${pkgs.coreutils}/bin/mkfifo "$main_fifo"
    printf '0' > "$latest_seq_file"
    trap '
      kill "''${curl_pid:-}" "''${parser_pid:-}" "''${claude_pid:-}" 2>/dev/null || true
      ${pkgs.coreutils}/bin/rm -f "$session_file" "$main_fifo" "$latest_msg_file" "$latest_seq_file" "$result_file"
    ' EXIT

    ${pkgs.curl}/bin/curl -N -s "''${MATTERBRIDGE_API}/api/stream" > "$main_fifo" &
    curl_pid=$!

    (
      while IFS= read -r line; do
        if [ -z "$line" ]; then
          continue
        fi
        json="$line"
        protocol=$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r '.protocol // empty')
        case "$protocol" in
          api|"") continue ;;
        esac
        text=$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r '.text // empty')
        if [ -z "$text" ]; then
          continue
        fi
        printf '%s' "$text" > "$latest_msg_file"
        seq=$(${pkgs.coreutils}/bin/cat "$latest_seq_file")
        printf '%d' "$((seq + 1))" > "$latest_seq_file"
      done < "$main_fifo"
    ) &
    parser_pid=$!

    claude_pid=""
    last_processed_seq=0
    was_interrupted=0
    waiting_for_reply=0

    while true; do
      current_seq=$(${pkgs.coreutils}/bin/cat "$latest_seq_file")

      if [ "$current_seq" -gt "$last_processed_seq" ]; then
        last_processed_seq="$current_seq"
        msg_text=$(${pkgs.coreutils}/bin/cat "$latest_msg_file")

        if [ -n "''${claude_pid:-}" ] && kill -0 "''${claude_pid:-}" 2>/dev/null; then
          kill "$claude_pid" 2>/dev/null
          wait "$claude_pid" 2>/dev/null || true
          was_interrupted=1
          : > "$session_file"
          claude_pid=""
        fi

        session_id=$(${pkgs.coreutils}/bin/cat "$session_file")

        if [ "$was_interrupted" = 1 ]; then
          was_interrupted=0
          input=$(printf '%s\n%s' '[System: 前の応答はユーザーの新しいメッセージにより中断されました]' "$msg_text")
        else
          input="$msg_text"
        fi

        if [ -z "$session_id" ]; then
          printf '%s' "$input" | ${claudeBin} -p --output-format json > "$result_file" 2>&1 &
        else
          printf '%s' "$input" | ${claudeBin} -p --resume "$session_id" --output-format json > "$result_file" 2>&1 &
        fi
        claude_pid=$!
        waiting_for_reply=1
      fi

      if [ "$waiting_for_reply" = 1 ] && [ -n "''${claude_pid:-}" ]; then
        if ! kill -0 "$claude_pid" 2>/dev/null; then
          if wait "$claude_pid"; then
            result=$(${pkgs.coreutils}/bin/cat "$result_file")
            printf '%s' "$result" | ${pkgs.jq}/bin/jq -r '.session_id // empty' > "$session_file"
            reply=$(printf '%s' "$result" | ${pkgs.jq}/bin/jq -r '.result // empty')
            if [ -n "$reply" ]; then
              ${pkgs.curl}/bin/curl -s -X POST "''${MATTERBRIDGE_API}/api/message" \
                -H 'Content-Type: application/json' \
                --data-binary "$(${pkgs.jq}/bin/jq -n --arg text "$reply" '{"text": $text, "gateway": "main"}')"
            fi
          else
            : > "$session_file"
          fi
          waiting_for_reply=0
          claude_pid=""
        fi
      fi

      ${pkgs.coreutils}/bin/sleep 0.1
    done
  '';
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
    templates."matterbridge-config" = {
      owner = "conao";
      content = ''
        [telegram.yui]
        Token="${config.sops.placeholder."matterbridge-telegram-token"}"

        [api.local]
        BindAddress="127.0.0.1:4242"

        [[gateway]]
        name="main"
        enable=true

            [[gateway.inout]]
            account="telegram.yui"
            channel="${config.sops.placeholder."matterbridge-telegram-chat-id"}"

            [[gateway.inout]]
            account="api.local"
            channel="api"
      '';
    };
    templates."helios-env" = {
      owner = "conao";
      content = ''
        export LINEAR_API_KEY=${config.sops.placeholder."linear-api-key"}
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
    secrets.matterbridge-telegram-token = { };
    secrets.matterbridge-telegram-chat-id = { };
    secrets.linear-api-key = { };
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

  services.matterbridge = {
    enable = true;
    user = "conao";
    configPath = config.sops.templates."matterbridge-config".path;
  };

  systemd.services.claude-telegram = {
    description = "Claude Telegram bot via matterbridge";
    after = [ "matterbridge.service" "network.target" ];
    wants = [ "matterbridge.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "conao";
      WorkingDirectory = "/home/conao";
      ExecStart = claudeTelegramScript;
      Restart = "always";
      RestartSec = "5";
    };
  };

  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };

  security.pki.certificateFiles = [ ../../secrets/dev-rootCA.pem ];

  zramSwap.enable = true;

  systemd.user.services.vm-agent-tunnel = {
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

  systemd.user.services.memory-alert = {
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

  systemd.user.timers.memory-alert = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
  };

  systemd.user.services.agent-memory-sync = {
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
