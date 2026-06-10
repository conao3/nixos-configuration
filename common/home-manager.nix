{
  lib,
  pkgs,
  inputs,
  homeProfile,
  ...
}:
{
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
      {
        home.homeDirectory = lib.mkForce "${
          if pkgs.stdenv.isDarwin then "/Users" else "/home"
        }/${homeProfile.user}";
      }
    ];
  };
}
