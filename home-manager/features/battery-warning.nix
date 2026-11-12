{ pkgs, ... }:
let
  battery-warning = pkgs.writeShellApplication {
    name = "battery-warning";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.pipewire
      pkgs.zenity
    ];
    text = ''
      bat=/sys/class/power_supply/BAT0
      sound=${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
      warned=100
      dialog=""

      show() {
        local level=$1
        if [ -n "$dialog" ]; then
          kill "$dialog" 2>/dev/null || true
        fi
        zenity --warning --title "電池の残りが少ない" --width 720 \
          --text "<span size='xx-large' weight='bold'>電池の残りが ''${level}% です</span>

      <span size='x-large'>電源につないでください。1% になると電源が切れます。</span>" &
        dialog=$!
        pw-play "$sound" &
      }

      while true; do
        capacity=$(cat "$bat/capacity")
        status=$(cat "$bat/status")
        if [ "$status" != "Discharging" ]; then
          warned=100
        else
          for threshold in 3 5 10; do
            if [ "$capacity" -le "$threshold" ]; then
              if [ "$threshold" -lt "$warned" ]; then
                warned=$threshold
                show "$capacity"
              fi
              break
            fi
          done
        fi
        sleep 30
      done
    '';
  };
in
{
  systemd.user.services.battery-warning = {
    Unit = {
      Description = "Show a dialog when the battery runs low";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${battery-warning}/bin/battery-warning";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
