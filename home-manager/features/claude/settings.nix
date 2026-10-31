{ pkgs, agentsLib, ... }:
let
  statusLineScript = pkgs.writeShellScript "claude-statusline" ''
    set -euo pipefail -o posix
    input="$(${pkgs.coreutils}/bin/cat)"
    email="$(${pkgs.jq}/bin/jq -r '.oauthAccount.emailAddress // empty' "''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.claude.json" 2>/dev/null || true)"
    model="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // empty')"
    used="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // empty')"
    dir="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir // .cwd // empty')"
    if [ -n "$used" ]; then
      model_info="$(printf '%s (%s%%)' "$model" "$used")"
    else
      model_info="$model"
    fi
    printf '%s | %s | %s' "$email" "$model_info" "$(${pkgs.coreutils}/bin/basename "$dir")"
  '';
in
{
  programs.agents.types.claude = {
    mcp = {
      format = "claude";
      key = "mcpServers";
      files = [
        "settings.json"
        ".claude.json"
      ];
    };
    files.".claude.json" = {
      scope = "instances";
      extraTargets = [ ".claude.json" ];
    };
    files."settings.json".settings = {
      theme = "dark";
      # spinner・shimmer・flash を減らし、端末 (wezterm の Software 描画) の再描画負荷を下げる
      prefersReducedMotion = true;
      permissions.defaultMode = "bypassPermissions";
      defaultMode = agentsLib.delete;
      skipDangerousModePermissionPrompt = true;
      cleanupPeriodDays = 9999;
      env = {
        CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "1";
        CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
        CLAUDE_CODE_ENABLE_TELEMETRY = "0";
        DISABLE_ERROR_REPORTING = "1";
        # DISABLE_TELEMETRY を設定すると GrowthBook の feature gate 取得が止まり、
        # gate 付き機能 (Monitor ツール等) がデフォルト OFF に落ちるため空文字へ遷移させる
        DISABLE_TELEMETRY = agentsLib.migrate {
          from = "1";
          to = "";
        };
        CDK_DISABLE_CLI_TELEMETRY = "true";
        SAM_CLI_TELEMETRY = "0";
        BASH_DEFAULT_TIMEOUT_MS = "300000";
        BASH_MAX_TIMEOUT_MS = "1200000";
      };
      # Remote Control (claude.ai/code とモバイルアプリからのセッション接続) の起動時 ON。
      # 明示設定が無いと GrowthBook の rollout gate (tengu_cobalt_harbor) 次第で OFF に落ちる
      remoteControlAtStartup = true;
      preferredNotifChannel = "terminal_bell";
      attribution = {
        commit = "";
        pr = "";
        # web / Remote Control セッションの commit・PR 本文へ付く Claude-Session トレーラーを外す
        sessionUrl = false;
      };
      language = "japanese";
      autoMemoryEnabled = false;
      autoMemoryDirectory = "~/.agents/share/auto-memory";
      statusLine = agentsLib.force {
        type = "command";
        command = "${statusLineScript}";
      };
      hooks = agentsLib.force {
        PreToolUse = [
          {
            matcher = "Write|Edit";
            hooks = [
              {
                type = "command";
                command = "clj-paren-repair-claude-hook --cljfmt";
              }
            ];
          }
        ];
        SessionStart = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "echo AGENTS.mdの「毎セッション開始時」セクションの指示に従い、必要なファイルを読み込んでください。";
              }
            ];
          }
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = ''
                  MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)" 2>/dev/null)"
                  CANONICAL=$(printf '%s\n' "$MAIN" | sed "s|^$HOME/||" | tr /. -)
                  echo "project_dir_canonical: $CANONICAL"
                '';
              }
            ];
          }
        ];
      };
    };
  };
}
