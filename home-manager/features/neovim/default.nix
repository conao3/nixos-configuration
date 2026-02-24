{ ... }:
{
  programs.neovim = {
    enable = true;
    extraConfig = builtins.readFile ./extraconfig.vim;
  };
}
