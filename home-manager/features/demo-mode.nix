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
      channels=(xfce4-power-manager xfce4-notifyd xsettings xsettings)
      properties=(/xfce4-power-manager/presentation-mode /do-not-disturb /Gtk/CursorThemeSize /Gtk/CursorThemeName)
      types=(bool bool int string)
      values=(true true 72 Adwaita)

      case "''${1:-on}" in
        on)
          if [[ ! -f "$state" ]]; then
            umask 077
            for i in 0 1 2 3; do
              xfconf-query -c "''${channels[$i]}" -p "''${properties[$i]}" 2>/dev/null || echo __missing__
            done > "$state"
          fi
          for i in 0 1 2 3; do
            xfconf-query -c "''${channels[$i]}" -p "''${properties[$i]}" \
              -n -t "''${types[$i]}" -s "''${values[$i]}"
          done
          if ! systemctl --user is-active --quiet demo-screenkey.service; then
            systemd-run --user --unit=demo-screenkey --collect \
              --setenv="DISPLAY=''${DISPLAY:?}" \
              --setenv="XAUTHORITY=''${XAUTHORITY:-}" \
              ${pkgs.screenkey}/bin/screenkey \
              --position bottom --font 'Sans 32' --timeout 1.5 \
              --bg-color '#202020' --font-color '#ffffff' --opacity 0.8
          fi
          if ! systemctl --user is-active --quiet demo-pointer.service; then
            systemd-run --user --unit=demo-pointer --collect \
              --setenv="DISPLAY=''${DISPLAY:?}" \
              --setenv="XAUTHORITY=''${XAUTHORITY:-}" \
              ${pkgs.highlight-pointer}/bin/highlight-pointer \
              --show-cursor --single-instance --force-raise \
              --radius 40 --outline 4 --opacity 0.85 \
              --released-color '#ffcc00' --pressed-color '#ff3030'
          fi
          echo 'Demo mode on: keys, enlarged cursor and click highlight enabled.'
          ;;
        off)
          systemctl --user stop demo-screenkey.service 2>/dev/null || true
          systemctl --user stop demo-pointer.service 2>/dev/null || true
          if [[ -f "$state" ]]; then
            mapfile -t saved < "$state"
            for i in 0 1 2 3; do
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
    pkgs.highlight-pointer
    demoMode
  ];
}
