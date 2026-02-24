{ ... }:
{
  programs.neovim = {
    enable = true;
    extraConfig = builtins.readFile ../ext/neovim-extraconfig.vim;
  };
}
