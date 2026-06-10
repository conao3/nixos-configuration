{
  pkgs,
  ...
}:
let
  portlessPackage = pkgs.callPackage ../../pkgs/portless.nix { };
in
{
  sops.secrets.portless-ca-key = {
    owner = "root";
    group = "root";
    mode = "0600";
    path = "/home/conao/.portless/ca-key.pem";
  };

  system.activationScripts.portless-state = ''
    mkdir -p /home/conao/.portless
    chown conao:users /home/conao/.portless
    chmod 755 /home/conao/.portless
    cp -f ${../../secrets/portless-ca.crt} /home/conao/.portless/ca.pem
    chmod 644 /home/conao/.portless/ca.pem
  '';

  systemd.services.portless-proxy = {
    description = "Portless HTTPS proxy (port 443)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment.PORTLESS_STATE_DIR = "/home/conao/.portless";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${portlessPackage}/bin/portless proxy start --foreground --port 443 --https --skip-trust";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
