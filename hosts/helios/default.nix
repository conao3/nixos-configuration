{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cagentBin = "/home/conao/ghq/github.com/conao3/rust-cagent/target/debug/cagent";
  cliProxyApiManagementCenterPackage =
    pkgs.callPackage ../../pkgs/cli-proxy-api-management-center.nix
      { };
in
{
  imports = [
    ./hardware-configuration.nix
    ./coding-agent.nix
    ./kill-orphan.nix
    ./memory.nix
    ./portless.nix
  ];

  networking.hostName = "conao-nixos-helios";
  networking.firewall.trustedInterfaces = [
    "docker0"
    "br-+"
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/conao/.config/sops/age/keys.txt";
    templates."cagent-config" = {
      owner = "conao";
      path = "/home/conao/.config/cagent/config.toml";
      content = ''
        claude_command = "claude.yui"
        claude_config_dir = "/home/conao/.agents/.claude.yui"

        [telegram]
        token = "${config.sops.placeholder."matterbridge-telegram-token"}"
        working_dir = "/home/conao/ghq"
      '';
    };
    templates."helios-env" = {
      owner = "conao";
      content = ''
        export LINEAR_API_KEY=${config.sops.placeholder."linear-api-key"}
        export DEVIN_API_KEY=${config.sops.placeholder."devin-api-key"}
        export N8N_API_KEY=${config.sops.placeholder."n8n-api-key"}
        export ANTHROPIC_WORKER_URL=https://cli-proxy-api.sancode.dev
        export ANTHROPIC_WORKER_API_TOKEN=${config.sops.placeholder."cli-proxy-api-key"}
        export PENPOT_MCP_KEY=${config.sops.placeholder."penpot-mcp-key"}
        export SAKANA_API_KEY=${config.sops.placeholder."sakana-api-key"}
      '';
    };
    templates."ollama-tunnel-script" = {
      owner = "conao";
      mode = "0500";
      content = ''
        #!/bin/sh
        exec ${config.sops.placeholder."ollama-tunnel-exec"}
      '';
    };
    secrets.matterbridge-telegram-token = { };
    secrets.linear-api-key = { };
    secrets.devin-api-key = { };
    secrets.n8n-api-key = { };
    secrets.cli-proxy-api-key = { };
    secrets.penpot-mcp-key = { };
    secrets.sakana-api-key = { };
    secrets.ollama-tunnel-exec = { };
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

  # cagent: disabled due to high memory usage (437M+), enable when needed
  # systemd.user.services.cagent = {
  #   description = "cagent server";
  #   after = [ "network.target" ];
  #   wantedBy = [ "default.target" ];
  #   path = [ "/etc/profiles/per-user/conao" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     WorkingDirectory = "/home/conao/ghq";
  #     ExecStart = "${cagentBin} server";
  #     Restart = "always";
  #     RestartSec = "5";
  #   };
  # };

  systemd.services.ollama-tunnel = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
    serviceConfig = {
      Type = "simple";
      User = "conao";
      WorkingDirectory = "/home/conao";
      ExecStart = "${pkgs.bash}/bin/bash ${config.sops.templates."ollama-tunnel-script".path}";
      Restart = "always";
      RestartSec = 30;
    };
  };

  security.pki.certificateFiles = [
    ../../secrets/dev-rootCA.pem
    ../../secrets/portless-ca.crt
  ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];

  systemd.user.services = {
    vm-agent-tunnel = {
      description = "SSH tunnel to agent-vm";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.autossh}/bin/autossh"
          "-M 0"
          "-N"
          "-p 2222"
          "-o ServerAliveInterval=10"
          "-o ServerAliveCountMax=3"
          "-o ExitOnForwardFailure=yes"
          "-o StrictHostKeyChecking=no"
          "-L 9119:127.0.0.1:9119"
          "-L 8787:127.0.0.1:8787"
          "-L 9120:127.0.0.1:3000"
          "-L 18789:127.0.0.1:18789"
          "-L 18792:127.0.0.1:18792"
          "-L 18701:127.0.0.1:18701"
          "conao@localhost"
        ];
        Restart = "always";
        RestartSec = "5";
        Environment = "AUTOSSH_GATETIME=0";
      };
    };

    agent-memory-sync = {
      description = "Sync ~/.agents and push encrypted agent-memory-data";
      serviceConfig = {
        Type = "oneshot";
        Environment = "GIT_SSH_COMMAND=${pkgs.openssh}/bin/ssh";
        ExecStart = "${pkgs.writeShellScript "agent-memory-sync" ''
          set -euxo pipefail -o posix
          repo_dir="$HOME/ghq/github.com/conao3/agent-memory-data"
          cd "$repo_dir"

          current_branch=$(${pkgs.git}/bin/git rev-parse --abbrev-ref HEAD)
          if [ "$current_branch" != "master" ]; then
            ${pkgs.git}/bin/git switch master
          fi
          ${pkgs.git}/bin/git fetch origin master
          ${pkgs.git}/bin/git rebase origin/master

          ${pkgs.nix}/bin/nix run .#sync-push
          ${pkgs.nix}/bin/nix run .#sync-pull

          ${pkgs.git}/bin/git add data
          if ${pkgs.git}/bin/git diff --cached --quiet; then
            exit 0
          fi

          ${pkgs.coreutils}/bin/env PATH=${lib.makeBinPath [ pkgs.git ]} \
            ${pkgs.gitleaks}/bin/gitleaks git --staged --redact --no-banner
          ${pkgs.git}/bin/git commit --no-verify -m "chore(memory): hourly sync"
          ${pkgs.git}/bin/git push origin master
        ''}";
      };
    };

    cli-proxy-api-management-center = {
      description = "CLIProxyAPI Management Center";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${cliProxyApiManagementCenterPackage}/bin/cli-proxy-api-management-center";
        Restart = "always";
        RestartSec = "5";
        Environment = [
          "CLIPROXY_MGMT_CENTER_HOST=127.0.0.1"
          "CLIPROXY_MGMT_CENTER_PORT=8788"
        ];
      };
    };
  };

  # systemd.user.timers.agent-memory-sync = {
  #   wantedBy = [ "timers.target" ];
  #   timerConfig = {
  #     OnBootSec = "3min";
  #     OnUnitActiveSec = "1h";
  #     Persistent = true;
  #     RandomizedDelaySec = "5min";
  #   };
  # };

}
