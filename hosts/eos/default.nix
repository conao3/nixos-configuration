{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    (inputs.nix-flakes + "/nixos/substituters.nix")
  ];

  networking.hostName = "conao-nixos-eos";

  time.timeZone = lib.mkForce "America/Toronto";

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/conao/.config/sops/age/keys.txt";
  };

  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  boot.kernelParams = [ "i915.enable_psr=0" ];

  # ThinkPad の充電しきい値。70% を下回ると充電を始め、80% で止める (80% 以上は AC から直接給電)。
  systemd.services.battery-charge-threshold = {
    description = "Set battery charge thresholds";
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
    after = [ "post-resume.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      bat=/sys/class/power_supply/BAT0
      echo 70 > $bat/charge_control_start_threshold
      echo 80 > $bat/charge_control_end_threshold
      echo 70 > $bat/charge_control_start_threshold
    '';
  };

  services.upower = {
    percentageAction = 1;
    criticalPowerAction = "PowerOff";
  };

  virtualisation.libvirtd.enable = lib.mkForce false;

  services.xserver.xkb.options = "ctrl:nocaps";
  console.useXkbConfig = true;

  services.xserver = {
    autoRepeatDelay = 300;
    autoRepeatInterval = 30;
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

  programs.steam = {
    remotePlay.openFirewall = lib.mkForce false;
    dedicatedServer.openFirewall = lib.mkForce false;
    localNetworkGameTransfers.openFirewall = lib.mkForce false;
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "2606:4700:4700::1111#cloudflare-dns.com"
        "2606:4700:4700::1001#cloudflare-dns.com"
      ];
      DNSOverTLS = "opportunistic";
      Domains = [ "~." ];
      LLMNR = false;
      MulticastDNS = false;
    };
  };

  networking.networkmanager = {
    dns = lib.mkForce "none";
    settings.main.systemd-resolved = false;
    wifi.macAddress = "stable";
    dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "open-wifi-no-autoconnect" ''
          [ "$2" = up ] || exit 0
          [ "$(${pkgs.networkmanager}/bin/nmcli -g connection.type connection show "$CONNECTION_UUID")" = 802-11-wireless ] || exit 0
          [ -z "$(${pkgs.networkmanager}/bin/nmcli -g 802-11-wireless-security.key-mgmt connection show "$CONNECTION_UUID")" ] || exit 0
          ${pkgs.networkmanager}/bin/nmcli connection modify "$CONNECTION_UUID" connection.autoconnect no
        '';
      }
    ];
  };

  networking.firewall = {
    trustedInterfaces = [
      "cni0"
      "flannel.1"
    ];
    extraCommands = ''
      iptables -t mangle -N eos-lan-dnat 2>/dev/null || true
      iptables -t mangle -F eos-lan-dnat
      iptables -t mangle -A eos-lan-dnat -m conntrack --ctstate DNAT --ctdir ORIGINAL -j DROP
      for iface in wl+ en+; do
        iptables -t mangle -C FORWARD -i "$iface" -j eos-lan-dnat 2>/dev/null \
          || iptables -t mangle -I FORWARD -i "$iface" -j eos-lan-dnat
      done
    '';
    extraStopCommands = ''
      for iface in wl+ en+; do
        iptables -t mangle -D FORWARD -i "$iface" -j eos-lan-dnat 2>/dev/null || true
      done
      iptables -t mangle -F eos-lan-dnat 2>/dev/null || true
      iptables -t mangle -X eos-lan-dnat 2>/dev/null || true
    '';
  };
}
