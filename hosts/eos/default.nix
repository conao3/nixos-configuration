{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "conao-nixos-eos";

  time.timeZone = lib.mkForce "America/Vancouver";

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/conao/.config/sops/age/keys.txt";
  };

  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  virtualisation.libvirtd.enable = lib.mkForce false;

  services.xserver.xkb.options = "ctrl:nocaps";
  console.useXkbConfig = true;

  services.xserver = {
    autoRepeatDelay = 300;
    autoRepeatInterval = 30;
  };
}
