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
in
{
  home = {
    stateVersion = "24.11";

    file.".config" = {
      source = ./ext/.config;
      recursive = true;
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

    activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings_file="$HOME/.claude/settings.json"
      if [ ! -f "$settings_file" ] || [ -L "$settings_file" ]; then
        rm -f "$settings_file"
        mkdir -p "$(dirname "$settings_file")"
        cat > "$settings_file" << 'SETTINGS_EOF'
      {
        "theme": "dark",
        "defaultMode": "acceptEdits",
        "env": {
          "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY": "1",
          "CLAUDE_CODE_ENABLE_TELEMETRY": "0",
          "DISABLE_ERROR_REPORTING": "1",
          "DISABLE_TELEMETRY": "1",
          "BASH_DEFAULT_TIMEOUT_MS": "300000",
          "BASH_MAX_TIMEOUT_MS": "1200000"
        },
        "includeCoAuthoredBy": false,
        "language": "japanese"
      }
      SETTINGS_EOF
      fi
      claude_json="$HOME/.claude.json"
      if [ ! -f "$claude_json" ] || ! jq -e '.hasCompletedOnboarding' "$claude_json" > /dev/null 2>&1; then
        tmp=$(mktemp)
        if [ -f "$claude_json" ]; then
          jq '. + {hasCompletedOnboarding: true}' "$claude_json" > "$tmp"
        else
          echo '{"hasCompletedOnboarding": true}' > "$tmp"
        fi
        mv "$tmp" "$claude_json"
        chmod 600 "$claude_json"
      fi
    '';

    shellAliases = {
      e = "$EDITOR";
    };

    packages =
      # https://search.nixos.org/packages
      (with pkgs; [
        gnumake
        google-chrome
        bottom                  # Rust re-implementation for top
        _1password-gui
        jq
        ripgrep
        fd
        tree
        python3
        file
        git
        nodejs
      ])
      ++ (with inputs.llm-agents.packages.${system}; [
        claude-code
        claude-code-acp
        codex
        codex-acp
        openclaw
      ]);
  };

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      siliconflow-api-key = { };
      openclaw-dot-env = {
        path = "${config.home.homeDirectory}/.openclaw/.env";
      };
      claude-credentials = {
        path = "${config.home.homeDirectory}/.claude/.credentials.json";
      };
      slack-bot-token = { };
      slack-app-token = { };
    };
  };

  programs = {
    # https://nix-community.github.io/home-manager/options.xhtml
    home-manager.enable = true;

    zsh = {
      enable = true;
      profileExtra = ''
        export SILICONFLOW_API_KEY="$(cat ${config.sops.secrets.siliconflow-api-key.path})"
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
    emacs.enable = true;
  };

  services.emacs = {
    enable = true;
    defaultEditor = true;
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
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  xdg.configFile."mimeapps.list".force = true;

  xdg.configFile."xfce4/helpers.rc" = {
    force = true;
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
