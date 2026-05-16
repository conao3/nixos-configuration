{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage ../../pkgs/birdclaw.nix { })
  ];
}
