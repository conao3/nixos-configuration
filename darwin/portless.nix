{
  pkgs,
  lib,
  username,
  ...
}:
let
  portlessPackage = pkgs.callPackage ../pkgs/portless.nix { };
  portlessStateDir = "/Users/${username}/.portless";
in
{
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    mkdir -p ${portlessStateDir}
    chown ${username}:staff ${portlessStateDir}
    chmod 2775 ${portlessStateDir}
    /usr/bin/find ${portlessStateDir} -mindepth 1 -type d \
      -exec chown ${username}:staff {} + \
      -exec chmod 2775 {} + 2>/dev/null || true
    /usr/bin/find ${portlessStateDir} -mindepth 1 -type f \
      ! -name 'ca-key.pem' ! -name 'server-key.pem' \
      -exec chown ${username}:staff {} + \
      -exec chmod 664 {} + 2>/dev/null || true

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
      Umask = 2;
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/var/log/portless-proxy.log";
      StandardErrorPath = "/var/log/portless-proxy.err.log";
    };
  };
}
