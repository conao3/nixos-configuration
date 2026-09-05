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

  nix.settings = {
    substituters = [
      # keep-sorted start
      "https://attmcojp.cachix.org"
      "https://motoki317-ksync.cachix.org"
      # keep-sorted end
    ];
    trusted-public-keys = [
      # keep-sorted start
      "attmcojp.cachix.org-1:oru6oV4EttotACGO/YDhmsEyPlPSytG6zWUgTRH3BMQ="
      "motoki317-ksync.cachix.org-1:uDM0RWapTkolNEgkcqQIGpmJc3bumFf+y3RYj50jQA0="
      # keep-sorted end
    ];
  };

  services.k3s = {
    enable = true;
    role = "server";
    disable = [ "traefik" ];
    extraFlags = [ "--write-kubeconfig-mode=0644" ];
  };

  systemd.services.k3s.serviceConfig.ExecStartPost = [
    "-${pkgs.writeShellScript "k3s-containerd-sock-access" ''
      sock=/run/k3s/containerd/containerd.sock
      for _ in $(seq 1 120); do
        if [ -S "$sock" ]; then
          chgrp docker "$sock"
          chmod 0660 "$sock"
          exit 0
        fi
        sleep 1
      done
      exit 1
    ''}"
  ];

  networking.firewall.trustedInterfaces = [
    "cni0"
    "flannel.1"
  ];
}
