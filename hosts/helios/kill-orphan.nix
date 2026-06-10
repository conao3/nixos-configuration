{
  pkgs,
  ...
}:
{
  systemd.user.services = {
    kill-orphan-vitest = {
      description = "Kill orphaned (PPID=1) or long-running (>30min) vitest processes";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "kill-orphan-vitest" ''
          set -uo pipefail
          MAX_ETIME=1800
          for pid in $(${pkgs.procps}/bin/pgrep -f 'node_modules/\.bin/vitest run' || true); do
            ppid=$(${pkgs.procps}/bin/ps -o ppid= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ')
            etime=$(${pkgs.procps}/bin/ps -o etimes= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ')
            [ "$ppid" = 1 ] || { [ -n "$etime" ] && [ "$etime" -gt "$MAX_ETIME" ]; } || continue
            ${pkgs.procps}/bin/pkill -9 -P "$pid" || true
            kill -9 "$pid" 2>/dev/null || true
          done
          for pid in $(${pkgs.procps}/bin/pgrep -f 'vitest/dist/workers/forks\.js' || true); do
            ppid=$(${pkgs.procps}/bin/ps -o ppid= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ')
            etime=$(${pkgs.procps}/bin/ps -o etimes= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ')
            [ "$ppid" = 1 ] || { [ -n "$etime" ] && [ "$etime" -gt "$MAX_ETIME" ]; } || continue
            kill -9 "$pid" 2>/dev/null || true
          done
        ''}";
      };
    };

    kill-orphan-portless = {
      description = "Kill orphaned (PPID=1) portless CLI wrappers (skip system portless-proxy)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "kill-orphan-portless" ''
          set -uo pipefail
          my_uid=$(${pkgs.coreutils}/bin/id -u)
          for pid in $(${pkgs.procps}/bin/pgrep -u "$my_uid" -f 'portless/dist/cli\.js' || true); do
            ppid=$(${pkgs.procps}/bin/ps -o ppid= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ')
            [ "$ppid" = 1 ] || continue
            ${pkgs.procps}/bin/pkill -9 -P "$pid" || true
            kill -9 "$pid" 2>/dev/null || true
          done
        ''}";
      };
    };

    kill-orphan-claude-print = {
      description = "Kill orphaned (PPID=1) claude --print processes (claude-app-server crash residue)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "kill-orphan-claude-print" ''
          set -uo pipefail
          my_uid=$(${pkgs.coreutils}/bin/id -u)
          for pid in $(${pkgs.procps}/bin/pgrep -u "$my_uid" -f 'claude --print' || true); do
            ppid=$(${pkgs.procps}/bin/ps -o ppid= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ')
            [ "$ppid" = 1 ] || continue
            kill -9 "$pid" 2>/dev/null || true
          done
        ''}";
      };
    };

    kill-orphan-lean = {
      description = "Kill orphaned (PPID=1) lean --run processes";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "kill-orphan-lean" ''
          set -uo pipefail
          my_uid=$(${pkgs.coreutils}/bin/id -u)
          for pid in $(${pkgs.procps}/bin/pgrep -u "$my_uid" -f 'lean --run' || true); do
            ppid=$(${pkgs.procps}/bin/ps -o ppid= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ')
            [ "$ppid" = 1 ] || continue
            ${pkgs.procps}/bin/pkill -9 -P "$pid" || true
            kill -9 "$pid" 2>/dev/null || true
          done
        ''}";
      };
    };
  };

  systemd.user.timers = {
    kill-orphan-vitest = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
      };
    };

    kill-orphan-portless = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
      };
    };

    kill-orphan-claude-print = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
      };
    };

    kill-orphan-lean = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "5min";
      };
    };
  };
}
