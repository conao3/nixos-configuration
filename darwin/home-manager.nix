{ inputs, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    ../common/home-manager.nix
  ];
}
