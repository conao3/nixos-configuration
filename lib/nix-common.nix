{
  pkgs,
  isNixOS ? false,
  ...
}:
{
  nix = {
    optimise.automatic = true;
    settings =
      {
        experimental-features = "nix-command flakes";
        max-jobs = 8;
      }
      // (
        if isNixOS then
          {
            trusted-users = [
              "root"
              "@wheel"
            ];
          }
        else
          { }
      );

    # Only add garbage collection for NixOS, darwin has its own
    gc =
      if isNixOS then
        {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        }
      else
        {
          automatic = true;
        };
  };

  # Always allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
