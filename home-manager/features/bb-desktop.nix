{
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    (pkgs.callPackage ../../pkgs/bb-desktop.nix { })
  ];
}
