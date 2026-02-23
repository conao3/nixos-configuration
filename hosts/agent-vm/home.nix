{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  username = config.home.username;
  homeDir = config.home.homeDirectory;
  commonHomeDir = ../../home-manager;
in
{
  home = {
    stateVersion = "24.11";

    file = {
      ".config" = {
        source = ./ext/.config;
        recursive = true;
      };
      ".claude" = {
        source = commonHomeDir + "/ext/.claude";
        recursive = true;
      };
      ".config/git/hooks/pre-commit" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail
          exec ${pkgs.gitleaks}/bin/gitleaks git --staged --redact --no-banner
        '';
      };
    };

    activation.openclawSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      openclaw_json="$HOME/.openclaw/openclaw.json"
      if [ -f "$openclaw_json" ]; then
        current_primary=$(jq -r '.agents.defaults.model.primary // ""' "$openclaw_json")
        if [ "$current_primary" != "openai-codex/gpt-5.3-codex" ]; then
          tmp=$(mktemp)
          jq \
            '.agents.defaults.model.primary = "openai-codex/gpt-5.3-codex" | .agents.defaults.model.fallbacks = ["custom-api-siliconflow-com-zai-org-glm-4-7/zai-org/GLM-4.7"]' \
            "$openclaw_json" > "$tmp" && mv "$tmp" "$openclaw_json"
        fi
        if [ "$(jq -r '.env.shellEnv.enabled // false' "$openclaw_json")" != "true" ]; then
          tmp=$(mktemp)
          jq '.env = {"shellEnv": {"enabled": true, "timeoutMs": 15000}}' \
            "$openclaw_json" > "$tmp" && mv "$tmp" "$openclaw_json"
        fi
        if [ "$(jq -r '.agents.defaults.contextTokens // 0' "$openclaw_json")" != "128000" ]; then
          tmp=$(mktemp)
          jq '.agents.defaults.contextTokens = 128000' \
            "$openclaw_json" > "$tmp" && mv "$tmp" "$openclaw_json"
        fi
        if [ "$(jq -r '.agents.defaults.compaction.mode // ""' "$openclaw_json")" != "default" ]; then
          tmp=$(mktemp)
          jq '.agents.defaults.compaction = {"mode": "default", "reserveTokensFloor": 40000}' \
            "$openclaw_json" > "$tmp" && mv "$tmp" "$openclaw_json"
        fi
        if [ "$(jq -r '.session.reset.idleMinutes // 0' "$openclaw_json")" != "30" ]; then
          tmp=$(mktemp)
          jq '.session.reset.idleMinutes = 30' \
            "$openclaw_json" > "$tmp" && mv "$tmp" "$openclaw_json"
        fi
        slack_bot=$(cat ${config.sops.secrets.slack-bot-token.path} 2>/dev/null || true)
        slack_app=$(cat ${config.sops.secrets.slack-app-token.path} 2>/dev/null || true)
        if [ -n "$slack_bot" ] && [ -n "$slack_app" ]; then
          current_bot=$(jq -r '.channels.slack.botToken // ""' "$openclaw_json")
          if [ "$current_bot" != "$slack_bot" ]; then
            tmp=$(mktemp)
            jq \
              --arg bot "$slack_bot" \
              --arg app "$slack_app" \
              '.channels.slack = {"enabled": true, "mode": "socket", "botToken": $bot, "appToken": $app}' \
              "$openclaw_json" > "$tmp" && mv "$tmp" "$openclaw_json"
          fi
        fi
      fi
    '';

    activation.ghSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            gh_token=$(cat ${config.sops.secrets.github-token.path} 2>/dev/null || true)
            if [ -n "$gh_token" ]; then
              gh_hosts="$HOME/.config/gh/hosts.yml"
              mkdir -p "$(dirname "$gh_hosts")"
              cat > "$gh_hosts" << EOF
      github.com:
          oauth_token: $gh_token
          git_protocol: ssh
          user: conao3
      EOF
              chmod 600 "$gh_hosts"
            fi
    '';

    activation.sshSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ssh_private=$(cat ${config.sops.secrets.ssh-private-key.path} 2>/dev/null || true)
      ssh_public=$(cat ${config.sops.secrets.ssh-public-key.path} 2>/dev/null || true)
      if [ -n "$ssh_private" ] && [ -n "$ssh_public" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        printf '%s\n' "$ssh_private" > "$HOME/.ssh/id_ed25519"
        chmod 600 "$HOME/.ssh/id_ed25519"
        printf '%s\n' "$ssh_public" > "$HOME/.ssh/id_ed25519.pub"
        chmod 644 "$HOME/.ssh/id_ed25519.pub"
      fi
    '';

    shellAliases = {
      e = "$EDITOR";
    };

    sessionVariables = {
      BEADS_DIR = "$HOME/dev/repos/openclaw-workspace/.beads";
    };

    packages =
      # https://search.nixos.org/packages
      # langages
      (with pkgs; [
        bun
        nodejs
        python3
        uv
        pnpm
      ])
      # rust re-impl
      ++ (with pkgs; [
        bat # cat
        bottom # top
        fd # find
        ripgrep # grep
        zellij # tmux
      ])
      # utils
      ++ (with pkgs; [
        _1password-gui
        file
        gh
        git
        gnumake
        google-chrome
        jq
        tmux
        tree
        lsof
      ])
      ++ (with inputs.llm-agents.packages.${system}; [
        claude-code
        claude-code-acp
        codex
        codex-acp
        openclaw
        qmd # vector search
        beads
      ])
      ++ [
        inputs.rust-fetch-usage-limit.packages.${system}.default
      ];
  };

  sops = {
    age.keyFile = "${homeDir}/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets/secrets.yaml;
    templates."agent-vm-env" = {
      content = ''
        SILICONFLOW_API_KEY=${config.sops.placeholder."siliconflow-api-key"}
      '';
    };
    secrets = {
      siliconflow-api-key = { };
      openclaw-dot-env = {
        path = "${homeDir}/.openclaw/.env";
      };
      slack-bot-token = { };
      slack-app-token = { };
      github-token = { };
      ssh-private-key = { };
      ssh-public-key = { };
    };
  };

  home.sessionPath = [ "${homeDir}/.openclaw/workspace/bin" ];

  programs = {
    # https://nix-community.github.io/home-manager/options.xhtml
    home-manager.enable = true;

    zsh = {
      enable = true;
      profileExtra = ''
        source ${config.sops.templates."agent-vm-env".path}
      '';
      initContent = ''
        _openclaw_auth_profiles="$HOME/.openclaw/agents/main/agent/auth-profiles.json"
        if [ ! -f "$_openclaw_auth_profiles" ] || \
           ! jq -e '.profiles | to_entries | map(select(.key | startswith("openai-codex"))) | length > 0' "$_openclaw_auth_profiles" > /dev/null 2>&1; then
          printf '[openclaw] OpenAI Codex not configured. Run: openclaw onboard --auth-choice openai-codex\n'
        fi
        unset _openclaw_auth_profiles
      '';
    };
    wezterm.enable = true;
    atuin = import (commonHomeDir + "/programs/atuin.nix");
    bash = import (commonHomeDir + "/programs/bash.nix");
    direnv = import (commonHomeDir + "/programs/direnv.nix");
    emacs = import (commonHomeDir + "/programs/emacs.nix") pkgs;
    git = lib.recursiveUpdate (import (commonHomeDir + "/programs/git.nix")) {
      settings.core.hooksPath = "~/.config/git/hooks";
    };
    neovim = import (commonHomeDir + "/programs/neovim.nix");
  };

  services = {
    emacs = {
      enable = true;
      defaultEditor = true;
    };
  };

  systemd.user.services.openclaw-gateway = {
    Unit = {
      Description = "OpenClaw Gateway";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${inputs.llm-agents.packages.${system}.openclaw}/bin/openclaw gateway run";
      Restart = "always";
      RestartSec = "5";
      KillMode = "process";
      Environment = [
        "PATH=${
          lib.concatStringsSep ":" [
            "${homeDir}/.openclaw/workspace/bin"
            "/run/wrappers/bin"
            "${homeDir}/.nix-profile/bin"
            "/nix/profile/bin"
            "${homeDir}/.local/state/nix/profile/bin"
            "/etc/profiles/per-user/${username}/bin"
            "/nix/var/nix/profiles/default/bin"
            "/run/current-system/sw/bin"
            "/usr/local/bin"
            "/usr/bin"
            "/bin"
          ]
        }"
      ];
      EnvironmentFile = config.sops.templates."agent-vm-env".path;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.qmd-mcp = {
    Unit = {
      Description = "QMD MCP Server (HTTP daemon)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${inputs.llm-agents.packages.${system}.qmd}/bin/qmd mcp --http";
      Restart = "always";
      RestartSec = "5";
      Environment = [
        "NODE_LLAMA_CPP_GPU=false"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.beads-ui = {
    Unit = {
      Description = "Beads UI";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "forking";
      PIDFile = "%t/beads-ui/server.pid";
      WorkingDirectory = "${homeDir}/.openclaw/workspace";
      ExecStart = "${pkgs.pnpm}/bin/pnpm dlx beads-ui start --port 18701";
      ExecStop = "${pkgs.pnpm}/bin/pnpm dlx beads-ui stop";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  xdg.configFile."mimeapps.list".force = true;

  xdg.configFile."xfce4/helpers.rc" = {
    text = ''
      WebBrowser=google-chrome
    '';
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };
}
