{ ... }:
{
  programs.zellij.enable = true;

  home.file = {
    ".config/zellij/config.kdl".source = ./config.kdl;
    ".config/zellij/layouts/sando.kdl".source = ./layouts/sando.kdl;
  };
}
