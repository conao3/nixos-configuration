{
  pkgs,
  lib,
  inputs,
  system,
  ...
}:
let
  inherit
    (import ./common.nix {
      inherit
        pkgs
        lib
        inputs
        system
        ;
    })
    claudeConfigDirs
    claudeJsonFiles
    mcpServers
    ;

  statusLineScript = pkgs.writeShellScript "claude-statusline" ''
    set -euo pipefail -o posix
    input="$(${pkgs.coreutils}/bin/cat)"
    email="$(${pkgs.jq}/bin/jq -r '.oauthAccount.emailAddress // empty' "''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.claude.json" 2>/dev/null || true)"
    model="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // empty')"
    dir="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir // .cwd // empty')"
    printf '%s | %s | %s' "$email" "$model" "$(${pkgs.coreutils}/bin/basename "$dir")"
  '';

  claudeSettings = {
    theme = "dark";
    defaultMode = "acceptEdits";
    skipDangerousModePermissionPrompt = true;
    cleanupPeriodDays = 9999;
    env = {
      CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "1";
      CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
      CLAUDE_CODE_ENABLE_TELEMETRY = "0";
      DISABLE_ERROR_REPORTING = "1";
      DISABLE_TELEMETRY = "1";
      CDK_DISABLE_CLI_TELEMETRY = "true";
      SAM_CLI_TELEMETRY = "0";
      BASH_DEFAULT_TIMEOUT_MS = "300000";
      BASH_MAX_TIMEOUT_MS = "1200000";
    };
    preferredNotifChannel = "terminal_bell";
    attribution = {
      commit = "";
      pr = "";
    };
    language = "japanese";
    autoMemoryEnabled = false;
    autoMemoryDirectory = "~/.agents/share/auto-memory";
  };

  statusLine = {
    type = "command";
    command = "${statusLineScript}";
  };
  statusLineJson = builtins.toJSON statusLine;
  applyStatusLine = ''
    ${pkgs.jq}/bin/jq --argjson statusLine '${statusLineJson}' '.statusLine = $statusLine' \
      "$settingsTarget" > "$settingsTarget.tmp" && mv "$settingsTarget.tmp" "$settingsTarget"
  '';

  flattenSettings =
    prefix: attrs:
    lib.concatLists (
      lib.mapAttrsToList (
        name: value:
        let
          path = "${prefix}.${name}";
        in
        if builtins.isAttrs value && value ? from && value ? to then
          [
            {
              inherit path;
              inherit (value) from to;
            }
          ]
        else if builtins.isAttrs value then
          flattenSettings path value
        else
          [
            {
              inherit path;
              from = null;
              to = value;
            }
          ]
      ) attrs
    );

  settingsPatches = flattenSettings "" claudeSettings;

  applyPatch =
    patch:
    let
      fromJson = builtins.toJSON patch.from;
      toJson = builtins.toJSON patch.to;
    in
    ''
      settingsCurrent=$(${pkgs.jq}/bin/jq -cS '${patch.path}' "$settingsTarget")
      settingsExpectedFrom=$(echo '${fromJson}' | ${pkgs.jq}/bin/jq -cS '.')
      settingsExpectedTo=$(echo '${toJson}' | ${pkgs.jq}/bin/jq -cS '.')
      if [ "$settingsCurrent" = "$settingsExpectedFrom" ]; then
        ${pkgs.jq}/bin/jq --argjson to '${toJson}' '${patch.path} = $to' \
          "$settingsTarget" > "$settingsTarget.tmp" && mv "$settingsTarget.tmp" "$settingsTarget"
      elif [ "$settingsCurrent" != "$settingsExpectedTo" ]; then
        printf '\033[1;33mWARN: claude settings: %s: ${patch.path}: expected %s or %s, got %s, skipping\033[0m\n' "$settingsTarget" "$settingsExpectedFrom" "$settingsExpectedTo" "$settingsCurrent" >> "$settingsWarnFile"
      fi
    '';

  hooks = {
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
    PreCompact = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "echo AGENTS.mdの「Compaction前」セクションの指示に従い、日次ログに作業状態を書き出してください。";
          }
        ];
      }
    ];
    SessionEnd = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "echo AGENTS.mdの「セッション終了時」セクションの指示に従い、個人記憶とチーム共通知識を見直してください。";
          }
        ];
      }
    ];
  };

  hooksJson = builtins.toJSON hooks;

  applyHooks = ''
    ${pkgs.jq}/bin/jq --argjson hooks '${hooksJson}' '.hooks = $hooks' \
      "$settingsTarget" > "$settingsTarget.tmp" && mv "$settingsTarget.tmp" "$settingsTarget"
  '';

  mcpServersJson = builtins.toJSON mcpServers;
  applyMcpServers = ''
    ${pkgs.jq}/bin/jq --argjson servers '${mcpServersJson}' '.mcpServers = $servers' \
      "$settingsTarget" > "$settingsTarget.tmp" && mv "$settingsTarget.tmp" "$settingsTarget"
  '';
in
{
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
    settingsWarnFile="$HOME/.claude/settings-warnings.log"
    rm -f "$settingsWarnFile"
    ${lib.concatMapStringsSep "\n" (dir: ''
      settingsTarget="${dir}/settings.json"
      if [ ! -f "$settingsTarget" ] || [ -L "$settingsTarget" ]; then
        rm -f "$settingsTarget"
        echo '{}' > "$settingsTarget"
      fi
      ${applyMcpServers}
      ${lib.concatMapStringsSep "\n" applyPatch settingsPatches}
      ${applyHooks}
      ${applyStatusLine}
    '') claudeConfigDirs}
    ${lib.concatMapStringsSep "\n" (file: ''
      settingsTarget="${file}"
      if [ ! -f "$settingsTarget" ] || [ -L "$settingsTarget" ]; then
        rm -f "$settingsTarget"
        echo '{}' > "$settingsTarget"
      fi
      ${applyMcpServers}
    '') claudeJsonFiles}
  '';
}
