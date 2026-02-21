{
  inputs,
  pkgs,
  config,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  username = config.home.username;
in
{
  home = {
    stateVersion = "24.11";

    file.".config" = {
      source = ./ext/.config;
      recursive = true;
    };

    shellAliases = {
      e = "$EDITOR";
    };

    packages =
      # https://search.nixos.org/packages
      (with pkgs; [
        gnumake
        google-chrome
        bottom                  # Rust re-implementation for top
        _1password-gui
      ])
      ++ (with inputs.llm-agents.packages.${system}; [
        claude-code
        claude-code-acp
        codex
        codex-acp
        openclaw
      ]);
  };

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      siliconflow-api-key = { };
    };
  };

  programs = {
    # https://nix-community.github.io/home-manager/options.xhtml
    home-manager.enable = true;

    zsh = {
      enable = true;
      profileExtra = ''
        export SILICONFLOW_API_KEY="$(cat ${config.sops.secrets.siliconflow-api-key.path})"
      '';
    };
    wezterm.enable = true;
    emacs.enable = true;
  };

  services.emacs = {
    enable = true;
    defaultEditor = true;
  };

  xdg.configFile."mimeapps.list".force = true;

  xdg.configFile."xfce4/helpers.rc" = {
    force = true;
    text = ''
      WebBrowser=google-chrome
    '';
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };
}
