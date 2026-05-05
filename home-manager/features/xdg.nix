{
  xdg.configFile."xfce4/helpers.rc" = {
    force = true;
    text = ''
      WebBrowser=firefox
      TerminalEmulator=wezterm
    '';
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
