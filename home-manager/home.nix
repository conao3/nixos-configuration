{
  config,
  pkgs,
  system,
  username,
  inputs,
  ...
}:

# https://home-manager-options.extranix.com/?query=&release=release-24.05
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # Import modular configs
  commonModule = import ./modules/common.nix { inherit username; };
  packagesModule = import ./modules/packages.nix {
    inherit
      pkgs
      username
      system
      inputs
      ;
  };
  programsModule = import ./modules/programs.nix { inherit pkgs; };
in
{
  imports = [
    # Import common configurations as modules
    commonModule
    packagesModule
    programsModule
  ];

  # Override platform-specific settings
  xsession.enable = !isDarwin;
  xfconf.enable = !isDarwin;
}
