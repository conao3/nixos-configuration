{ inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../common/home-manager.nix
  ];
}
