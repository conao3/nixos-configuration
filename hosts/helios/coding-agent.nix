{
  lib,
  pkgs,
  ...
}:
let
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
  systemd.user.services = codingAgentServices;

  systemd.user.timers = codingAgentTimers;
}
