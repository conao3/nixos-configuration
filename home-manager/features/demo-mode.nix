{ pkgs, ... }:
let
  demoMode = pkgs.writeShellApplication {
    name = "demo-mode";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.xfconf
    ];
    text = ''
      state="''${XDG_RUNTIME_DIR:?}/demo-mode-state"
      channels=(xfce4-power-manager xfce4-notifyd xsettings)
      properties=(/xfce4-power-manager/presentation-mode /do-not-disturb /Gtk/CursorThemeSize)
      types=(bool bool int)
      values=(true true 48)

      case "''${1:-on}" in
        on)
          if [[ ! -f "$state" ]]; then
            umask 077
            for i in 0 1 2; do
              xfconf-query -c "''${channels[$i]}" -p "''${properties[$i]}" 2>/dev/null || echo __missing__
            done > "$state"
          fi
          for i in 0 1 2; do
            xfconf-query -c "''${channels[$i]}" -p "''${properties[$i]}" \
              -n -t "''${types[$i]}" -s "''${values[$i]}"
          done
          if ! systemctl --user is-active --quiet demo-screenkey.service; then
            systemd-run --user --unit=demo-screenkey --collect \
              --setenv="DISPLAY=''${DISPLAY:?}" \
              --setenv="XAUTHORITY=''${XAUTHORITY:-}" \
              ${pkgs.screenkey}/bin/screenkey --mouse --mouse-fade 0.7 \
              --position bottom --font 'Sans 32' --timeout 1.5 \
              --bg-color '#202020' --font-color '#ffffff' --opacity 0.8
          fi
          echo 'Demo mode on: keys and mouse buttons shown; notifications and automatic sleep suppressed.'
          ;;
        off)
          systemctl --user stop demo-screenkey.service 2>/dev/null || true
          if [[ -f "$state" ]]; then
            mapfile -t saved < "$state"
            for i in 0 1 2; do
              if [[ "''${saved[$i]}" == __missing__ ]]; then
                xfconf-query -c "''${channels[$i]}" -p "''${properties[$i]}" -r || true
              else
                xfconf-query -c "''${channels[$i]}" -p "''${properties[$i]}" \
                  -n -t "''${types[$i]}" -s "''${saved[$i]}"
              fi
            done
            rm "$state"
          fi
          echo 'Demo mode off; previous desktop settings restored.'
          ;;
        *) echo 'Usage: demo-mode [on|off]' >&2; exit 2 ;;
      esac
    '';
  };
in
{
  home.packages = [
    pkgs.screenkey
    demoMode
  ];
}
