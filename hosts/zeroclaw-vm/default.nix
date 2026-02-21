{
  pkgs,
  inputs,
  ...
}:

{
  system.stateVersion = "24.11";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.conao = {
    isNormalUser = true;
    initialPassword = "conao";
    extraGroups = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = [
    inputs.llm-agents.packages.${pkgs.system}.zeroclaw
  ];

  services = {
    xserver = {
      enable = true;
      desktopManager.xfce.enable = true;
    };
    displayManager.defaultSession = "xfce";
  };

}
