{
  inputs,
  pkgs,
  ...
}:

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

    packages = [
      inputs.llm-agents.packages.${pkgs.system}.zeroclaw
      pkgs.wezterm
    ];
  };

  services.emacs = {
    enable = true;
    defaultEditor = true;
  };
}
