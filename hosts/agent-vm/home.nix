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
        bottom                  # Rust re-implementation for top
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
      initContent = ''
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
}
