{ pkgs, ... }:
let
  charge = pkgs.writeShellApplication {
    name = "battery-charge-limit";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      state=/var/lib/battery-charge-threshold
      bat=/sys/class/power_supply/BAT0
      exec 9>/run/lock/battery-charge-threshold.lock
      flock 9
      install -d -m 0755 "$state"
      case "$1" in
        80|100) limit=$1 ;;
        apply)
          limit=80
          if [ -f "$state/limit" ]; then
            limit=$(cat "$state/limit")
          fi
          ;;
        *) echo "Expected 80, 100 or apply" >&2; exit 1 ;;
      esac
      case "$limit" in
        80) start=70 ;;
        100) start=99 ;;
        *) echo "Invalid saved charge limit: $limit" >&2; exit 1 ;;
      esac
      echo 100 > "$bat/charge_control_end_threshold"
      echo "$start" > "$bat/charge_control_start_threshold"
      echo "$limit" > "$bat/charge_control_end_threshold"
      test "$(cat "$bat/charge_control_start_threshold")" = "$start"
      test "$(cat "$bat/charge_control_end_threshold")" = "$limit"
      echo "$limit" > "$state/limit.new"
      chmod 0644 "$state/limit.new"
      mv "$state/limit.new" "$state/limit"
    '';
  };
in
{
  environment.systemPackages = [ charge ];
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands =
        map
          (limit: {
            command = "${charge}/bin/battery-charge-limit ${limit}";
            options = [ "NOPASSWD" ];
          })
          [
            "80"
            "100"
          ];
    }
  ];
  systemd.services.battery-charge-threshold = {
    description = "Restore selected battery charge limit";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${charge}/bin/battery-charge-limit apply";
    };
  };
  powerManagement.resumeCommands = "${charge}/bin/battery-charge-limit apply";
  nixpkgs.overlays = [
    (final: prev: {
      xfce4-power-manager = prev.xfce4-power-manager.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./battery-menu.patch ];
        postPatch = (old.postPatch or "") + ''
          substituteInPlace panel-plugins/power-manager-plugin/power-manager-button.c \
            --replace-fail '@batteryChargeHelper@' '${charge}/bin/battery-charge-limit'
        '';
      });
    })
  ];
}
