{ pkgs, ... }:
let
  setRate = pkgs.writeShellApplication {
    name = "internal-panel-120hz";
    runtimeInputs = [ pkgs.xorg.xrandr ];
    text = ''
      sleep 5
      xrandr --output eDP-1 --mode 2560x1600 --rate 120
    '';
  };
in
{
  xdg.configFile."autostart/internal-panel-120hz.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Internal panel 120Hz
    Exec=${setRate}/bin/internal-panel-120hz
    X-GNOME-Autostart-enabled=true
  '';
}
