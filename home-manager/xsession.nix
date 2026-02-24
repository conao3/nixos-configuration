{ pkgs, ... }:
{
  xsession = {
    enable = !pkgs.stdenv.isDarwin;
    initExtra = "xset r rate 200 50";
  };
}
