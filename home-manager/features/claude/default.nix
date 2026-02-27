{
  pkgs,
  lib,
  inputs,
  system,
  ...
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
  claudeBin = "${llmAgents.claude-code}/bin/claude";
  codexBin = "${llmAgents.codex}/bin/codex";

  wrapperSpecs = [
    {
      name = "claude.conao3";
      bin = claudeBin;
      envKey = "CLAUDE_CONFIG_DIR";
      dir = ".agents/.claude.conao3";
    }
    {
      name = "claude.toyokumo";
      bin = claudeBin;
      envKey = "CLAUDE_CONFIG_DIR";
      dir = ".agents/.claude.toyokumo";
    }
    {
      name = "claude.agent001";
      bin = claudeBin;
      envKey = "CLAUDE_CONFIG_DIR";
      dir = ".agents/.claude.agent001";
    }
    {
      name = "codex.conao3";
      bin = codexBin;
      envKey = "CODEX_HOME";
      dir = ".agents/.codex.conao3";
    }
    {
      name = "codex.agent001";
      bin = codexBin;
      envKey = "CODEX_HOME";
      dir = ".agents/.codex.agent001";
    }
  ];

  mkWrapper = spec:
    pkgs.runCommand spec.name { buildInputs = [ pkgs.makeWrapper ]; } ''
      makeWrapper ${spec.bin} $out/bin/${spec.name} \
        --set ${spec.envKey} "$HOME/${spec.dir}"
    '';

  wrapperPackages = map mkWrapper wrapperSpecs;
  agentDirs = [ "$HOME/.agents" ] ++ map (spec: "$HOME/${spec.dir}") wrapperSpecs;

  # { path = ".theme"; from = null; to = "dark"; }
  settingsPatches = [
    { path = ".theme"; from = null; to = "dark"; }
    { path = ".defaultMode"; from = null; to = "acceptEdits"; }
    { path = ".skipDangerousModePermissionPrompt"; from = null; to = true; }
    { path = ".env.CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR"; from = null; to = "1"; }
    { path = ".env.CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY"; from = null; to = "1"; }
    { path = ".env.CLAUDE_CODE_ENABLE_TELEMETRY"; from = null; to = "0"; }
    { path = ".env.DISABLE_ERROR_REPORTING"; from = null; to = "1"; }
    { path = ".env.DISABLE_TELEMETRY"; from = null; to = "1"; }
    { path = ".env.CDK_DISABLE_CLI_TELEMETRY"; from = null; to = "true"; }
    { path = ".env.SAM_CLI_TELEMETRY"; from = null; to = "0"; }
    { path = ".env.BASH_DEFAULT_TIMEOUT_MS"; from = null; to = "300000"; }
    { path = ".env.BASH_MAX_TIMEOUT_MS"; from = null; to = "1200000"; }
    { path = ".preferredNotifChannel"; from = null; to = "terminal_bell"; }
    { path = ".includeCoAuthoredBy"; from = null; to = false; }
    { path = ".language"; from = null; to = "japanese"; }
  ];

  applyPatch = patch: let
    fromJson = builtins.toJSON patch.from;
    toJson = builtins.toJSON patch.to;
  in ''
    settingsCurrent=$(${pkgs.jq}/bin/jq -c '${patch.path}' "$settingsTarget")
    if [ "$settingsCurrent" = '${fromJson}' ]; then
      ${pkgs.jq}/bin/jq --argjson to '${toJson}' '${patch.path} = $to' \
        "$settingsTarget" > "$settingsTarget.tmp" && mv "$settingsTarget.tmp" "$settingsTarget"
    elif [ "$settingsCurrent" != '${toJson}' ]; then
      printf '\033[1;33mWARN: claude settings: ${patch.path}: expected ${fromJson} or ${toJson}, got %s, skipping\033[0m\n' "$settingsCurrent" >> "$settingsWarnFile"
    fi
  '';
in
{
  home.file = {
    ".claude" = {
      source = ./dotclaude;
      recursive = true;
    };
    ".config/Claude/claude_desktop_config.json" = {
      text = builtins.toJSON {
        globalShortcut = "Alt+Cmd+Space";
        mcpServers = {
          claude-code = {
            command = claudeBin;
            args = [
              "mcp"
              "serve"
            ];
          };
        };
      };
    };
  };

  home.packages = wrapperPackages;

  home.activation.ensureAgentDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatMapStringsSep "\n" (dir: "mkdir -p ${lib.escapeShellArg dir}") agentDirs}
  '';

  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settingsTarget="$HOME/.claude/settings.json"
    settingsWarnFile="$HOME/.claude/settings-warnings.log"
    rm -f "$settingsWarnFile"
    if [ ! -f "$settingsTarget" ] || [ -L "$settingsTarget" ]; then
      rm -f "$settingsTarget"
      echo '{}' > "$settingsTarget"
    fi
    ${lib.concatMapStringsSep "\n" applyPatch settingsPatches}
  '';

  programs.git.ignores = [
    ".claude"
    ".claude-dev"
  ];
}
