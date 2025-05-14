{
  username,
  system,
  inputs,
  mainPkgs,
  forMacos ? false,
}:
let
  homeDirectory = if forMacos then "/Users/${username}" else "/home/${username}";
in
{
  useGlobalPkgs = true;
  useUserPackages = true;
  backupFileExtension = "backup";

  extraSpecialArgs = {
    inherit username inputs;
    system = system;
    pkgs = mainPkgs;
  };

  users.${username} = import ../home-manager/home.nix;

  sharedModules =
    [
      # Set home directory explicitly with mkForce to ensure it overrides any other settings
      (
        { config, lib, ... }:
        {
          home.homeDirectory = lib.mkForce homeDirectory;
        }
      )
    ]
    ++ (
      if forMacos then
        [
          inputs.mac-app-util.homeManagerModules.default
        ]
      else
        [ ]
    );
}
