{
  inputs,
  pkgs,
  ...
}:

{
  home.stateVersion = "24.11";

  home.packages = [
    inputs.llm-agents.packages.${pkgs.system}.zeroclaw
  ];
}
