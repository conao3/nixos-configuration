{
  lib,
  pkgs,
  ...
}:
{
  services.k3s = {
    enable = true;
    role = "server";
    disable = [ "traefik" ];
    extraFlags = [ "--write-kubeconfig-mode=0644" ];
  };

  systemd.services.k3s.wantedBy = lib.mkForce [ ];

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
}
