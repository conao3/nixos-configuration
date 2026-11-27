{
  config,
  ...
}:
{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/home/conao/.config/sops/age/keys.txt";
    templates."helios-env" = {
      owner = "conao";
      content = ''
        export DEVIN_API_KEY=${config.sops.placeholder."devin-api-key"}
        export N8N_API_KEY=${config.sops.placeholder."n8n-api-key"}
        export ANTHROPIC_WORKER_URL=https://cli-proxy-api.sancode.dev
        export ANTHROPIC_WORKER_API_TOKEN=${config.sops.placeholder."cli-proxy-api-key"}
        export PENPOT_MCP_KEY=${config.sops.placeholder."penpot-mcp-key"}
        export SAKANA_API_KEY=${config.sops.placeholder."sakana-api-key"}
      '';
    };
    secrets.devin-api-key = {
      owner = "conao";
      path = "/home/conao/.config/devin-mcp/key";
    };
    secrets.n8n-api-key = { };
    secrets.cli-proxy-api-key = { };
    secrets.penpot-mcp-key = { };
    secrets.sakana-api-key = { };
    secrets.dev-ca-key = {
      owner = "conao";
      path = "/home/conao/.local/share/dev-ca/rootCA-key.pem";
    };
  };

  programs.zsh.interactiveShellInit = ''
    [ -f ${config.sops.templates."helios-env".path} ] && source ${
      config.sops.templates."helios-env".path
    }
  '';

  security.pki.certificateFiles = [
    ../secrets/dev-rootCA.pem
  ];
}
