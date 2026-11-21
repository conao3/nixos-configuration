{ modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  system.stateVersion = "26.11";

  networking.hostName = "conao-nixos-minimal";

  users.users.conao = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "conao";
  };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = "conao";

  virtualisation = {
    memorySize = 1024;
    cores = 2;
    graphics = false;
  };
}
