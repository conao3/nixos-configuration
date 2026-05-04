{ ... }:
{
  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    extraConfig = builtins.readFile ./extraconfig.vim;
    # extraPackages = [
    #   pkgs.deno
    # ];
  };
}
