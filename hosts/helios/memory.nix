{
  pkgs,
  ...
}:
{
  zramSwap.enable = true;

  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
    extraConfig = {
      DefaultMemoryPressureLimit = "50%";
      DefaultMemoryPressureDurationSec = "20s";
      SwapUsedLimit = "80%";
    };
  };

  systemd.slices."user".sliceConfig = {
    MemoryHigh = "38G";
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
}
