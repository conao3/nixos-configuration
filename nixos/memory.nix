{
  config,
  pkgs,
  ...
}:
let
  binPath = pkgs.lib.makeBinPath [
    pkgs.coreutils
    pkgs.gawk
    pkgs.libnotify
    pkgs.systemd
    pkgs.zenity
  ];
  topCgroups = pkgs.writeShellScript "memory-top-cgroups" ''
    systemd-cgtop -m -b -n 1 --depth=6 -r 2>/dev/null \
      | awk '$1 ~ /\.(scope|service)$/ && $1 !~ /user@[0-9]+\.service$/ && $4 ~ /^[0-9]+$/ {
          n = split($1, p, "/"); name = p[n]
          if (name ~ /^cri-containerd-/) name = "k3s pod " substr(name, 16, 12)
          printf "%5.1f GiB  %s\n", $4 / 1073741824, name
        }' \
      | sort -rn | head -5
  '';
  alert = pkgs.writeShellScript "memory-alert" ''
    set -eu -o pipefail
    export PATH=${binPath}
    state="$XDG_RUNTIME_DIR/memory-alert"
    mkdir -p "$state"
    now=$(date +%s)
    since() {
      if [ -f "$state/$1" ]; then echo $((now - $(cat "$state/$1"))); else echo 999999; fi
    }
    usage=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf "%d", (t - a) * 100 / t}' /proc/meminfo)
    if [ "$usage" -ge 90 ]; then
      if ! systemctl --user is-active -q memory-alert-dialog.service && [ "$(since dialog-closed)" -ge 600 ]; then
        text=$(printf 'メモリの使用率が %d%% です。\nこのまま 100%% になると画面が固まります。不要なアプリを閉じてください。\n\nメモリを多く使っているもの:\n%s' "$usage" "$(${topCgroups})")
        systemd-run --user --quiet --collect --unit=memory-alert-dialog \
          ${pkgs.bash}/bin/bash -c '${pkgs.zenity}/bin/zenity --warning --no-markup --width=520 --title="メモリ不足" --text="$1"; ${pkgs.coreutils}/bin/date +%s > "$2"' \
          memory-alert-dialog "$text" "$state/dialog-closed"
      fi
    elif [ "$usage" -ge 80 ] && [ "$(since notified)" -ge 300 ]; then
      echo "$now" > "$state/notified"
      notify-send -u critical "Memory Alert" "Memory usage: ''${usage}%"
    fi
  '';
  oomdWatch = pkgs.writeShellScript "memory-oomd-watch" ''
    set -u
    export PATH=${binPath}
    journalctl -f -n 0 -o cat -u systemd-oomd.service | while IFS= read -r line; do
      case "$line" in
        Killed*)
          systemd-run --user --quiet --collect \
            ${pkgs.zenity}/bin/zenity --error --no-markup --width=520 --title="メモリ不足でアプリを終了しました" \
            --text="$(printf 'systemd-oomd がメモリ不足のため次のものを終了しました。\n\n%s' "$line")"
          ;;
      esac
    done
  '';
in
{
  zramSwap.enable = true;

  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
    settings.OOM = {
      DefaultMemoryPressureLimit = "50%";
      DefaultMemoryPressureDurationSec = "20s";
      SwapUsedLimit = "80%";
    };
  };
  systemd.services.systemd-oomd.restartTriggers = [
    config.environment.etc."systemd/oomd.conf".source
  ];

  programs.atop = {
    enable = true;
    atopService.enable = true;
    atopRotateTimer.enable = true;
  };
  environment.etc."default/atop".text = ''
    LOGINTERVAL=30
    LOGGENERATIONS=7
  '';

  systemd.user.services.memory-alert = {
    description = "Memory usage alert";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = alert;
    };
  };

  systemd.user.timers.memory-alert = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "15s";
      AccuracySec = "1s";
    };
  };

  systemd.user.services.memory-oomd-watch = {
    description = "Show a dialog when systemd-oomd kills a cgroup";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = oomdWatch;
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
