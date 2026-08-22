{ ... }:

{
  services.sunshine = {
    enable = true;
    settings = {
      sunshine_name = "helios";
      encoder = "vaapi";
      adapter_name = "/dev/dri/renderD129";
      capture = "x11";
      origin_web_ui_allowed = "pc";
      min_log_level = "info";
    };
    applications.apps = [
      {
        name = "Desktop";
        image-path = "desktop.png";
      }
    ];
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      47984
      47989
      47990
      48010
    ];
    allowedUDPPorts = [
      47998
      47999
      48000
      48002
      48010
    ];
  };
}
