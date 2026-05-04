{ inputs, ... }:
{
  imports = [ (inputs.home-manager-worktrunk + "/modules/programs/worktrunk.nix") ];

  programs.worktrunk.enable = true;
}
