{
  inputs,
  pkgs,
  ...
}:

{
  home.stateVersion = "24.11";

  home.file.".config" = {
    source = ./ext/.config;
    recursive = true;
  };

  home.packages = [
    inputs.llm-agents.packages.${pkgs.system}.zeroclaw
    pkgs.emacs
    pkgs.wezterm
  ];
}
