{ pkgs, username, ... }:
let
  portlessPackage = pkgs.callPackage ../pkgs/portless.nix { };
  portlessStateDir = "/Users/${username}/.portless";
in
{
  system.activationScripts.portlessState.text = ''
    mkdir -p ${portlessStateDir}
    chown ${username}:staff ${portlessStateDir}
    chmod 755 ${portlessStateDir}

    if [ -f ${portlessStateDir}/ca.pem ]; then
      /usr/bin/security add-trusted-cert -d -r trustRoot \
        -k /Library/Keychains/System.keychain \
        ${portlessStateDir}/ca.pem || true
    fi
  '';

  launchd.daemons.portless-proxy = {
    serviceConfig = {
      Label = "org.nixos.portless-proxy";
      ProgramArguments = [
        "${portlessPackage}/bin/portless"
        "proxy"
        "start"
        "--foreground"
        "--port"
        "443"
        "--https"
        "--skip-trust"
      ];
      EnvironmentVariables = {
        PORTLESS_STATE_DIR = portlessStateDir;
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/var/log/portless-proxy.log";
      StandardErrorPath = "/var/log/portless-proxy.err.log";
    };
  };
}
