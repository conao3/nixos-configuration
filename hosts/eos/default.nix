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

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/conao/.config/sops/age/keys.txt";
  };

  virtualisation.libvirtd.enable = lib.mkForce false;

  services.xserver.xkb.options = "ctrl:nocaps";
  console.useXkbConfig = true;

  services.xserver = {
    autoRepeatDelay = 300;
    autoRepeatInterval = 30;
  };
}
