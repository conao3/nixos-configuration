{ config, username, ... }:
{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/Users/${username}/.config/sops/age/keys.txt";
    templates."darwin-env" = {
      owner = username;
      content = ''
        export SAKANA_API_KEY=${config.sops.placeholder."sakana-api-key"}
      '';
    };
    secrets.sakana-api-key = { };
  };

  programs.zsh.interactiveShellInit = ''
    [ -f ${config.sops.templates."darwin-env".path} ] && source ${
      config.sops.templates."darwin-env".path
    }
  '';
}
