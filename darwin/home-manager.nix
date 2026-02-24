{
  pkgs,
  inputs,
  homeProfile,
  ...
}:
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      username = homeProfile.user;
      inherit inputs;
      system = pkgs.stdenv.hostPlatform.system;
    };
    users.${homeProfile.user} = {
      imports = homeProfile.modules;
    };
    sharedModules = [
      (
        { lib, ... }:
        {
          home.homeDirectory = lib.mkForce "/Users/${homeProfile.user}";
        }
      )
    ];
  };
}
