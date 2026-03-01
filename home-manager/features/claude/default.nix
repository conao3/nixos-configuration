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
      type = "claude";
      name = "claude.conao3";
      bin = claudeBin;
      envKey = "CLAUDE_CONFIG_DIR";
      dir = ".agents/.claude.conao3";
    }
    {
      type = "claude";
      name = "claude.toyokumo";
      bin = claudeBin;
      envKey = "CLAUDE_CONFIG_DIR";
      dir = ".agents/.claude.toyokumo";
    }
    {
      type = "claude";
      name = "claude.agent001";
      bin = claudeBin;
      envKey = "CLAUDE_CONFIG_DIR";
      dir = ".agents/.claude.agent001";
    }
    {
      type = "claude";
      name = "claude.yui";
      bin = claudeBin;
      envKey = "CLAUDE_CONFIG_DIR";
      dir = ".agents/.claude.yui";
    }
    {
      type = "codex";
      name = "codex.conao3";
      bin = codexBin;
      envKey = "CODEX_HOME";
      dir = ".agents/.codex.conao3";
    }
    {
      type = "codex";
      name = "codex.agent001";
      bin = codexBin;
      envKey = "CODEX_HOME";
      dir = ".agents/.codex.agent001";
    }
  ];

  mkWrapper = spec:
    pkgs.runCommand spec.name { buildInputs = [ pkgs.makeWrapper ]; } ''
      makeWrapper ${spec.bin} $out/bin/${spec.name} \
        --run 'export ${spec.envKey}="$HOME/${spec.dir}"'
    '';

  soulTemplate = pkgs.writeText "SOUL.md" (builtins.readFile ./SOUL.md);
  identityTemplate = pkgs.writeText "IDENTITY.md" (builtins.readFile ./IDENTITY.md);

  wrapperPackages = map mkWrapper wrapperSpecs;
  agentDirs = [ "$HOME/.agents" "$HOME/.agents/share" ] ++ map (spec: "$HOME/${spec.dir}") wrapperSpecs;
  claudeConfigDirs =
    [ "$HOME/.claude" ]
    ++ map (spec: "$HOME/${spec.dir}") (builtins.filter (spec: spec.type == "claude") wrapperSpecs);
  codexConfigDirs =
    [ "$HOME/.codex" ]
    ++ map (spec: "$HOME/${spec.dir}") (builtins.filter (spec: spec.type == "codex") wrapperSpecs);
  claudeJsonFiles =
    [ "$HOME/.claude.json" ]
    ++ map (spec: "$HOME/${spec.dir}/.claude.json") (builtins.filter (spec: spec.type == "claude") wrapperSpecs);

  claudeSettings = {
    theme = "dark";
    defaultMode = "acceptEdits";
    skipDangerousModePermissionPrompt = true;
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
    includeCoAuthoredBy = false;
    language = "japanese";
  };

  flattenSettings = prefix: attrs:
    lib.concatLists (lib.mapAttrsToList (
      name: value: let
        path = "${prefix}.${name}";
      in
        if builtins.isAttrs value && value ? from && value ? to then
          [ { inherit path; inherit (value) from to; } ]
        else if builtins.isAttrs value then
          flattenSettings path value
        else
          [ { inherit path; from = null; to = value; } ]
    ) attrs);

  claudeMcpServers = {
    mcpServers = {
      chrome_devtools = {
        command = "npx";
        args = [ "chrome-devtools-mcp@latest" ];
      };
      deepwiki = {
        type = "http";
        url = "https://mcp.deepwiki.com/mcp";
      };
    };
  };

  codexConfig = {
    mcp_servers = {
      chrome_devtools = {
        command = "npx";
        args = [
          "-y"
          "chrome-devtools-mcp@latest"
        ];
      };
      deepwiki = {
        url = "https://mcp.deepwiki.com/mcp";
      };
    };
  };

  settingsPatches = flattenSettings "" claudeSettings;
  mcpPatches = flattenSettings "" claudeMcpServers;
  codexServerNames = builtins.attrNames codexConfig.mcp_servers;
  flattenCodexConfig = prefix: attrs:
    lib.concatLists (lib.mapAttrsToList (
      name: value:
      let
        path = if prefix == "" then name else "${prefix}.${name}";
      in
      if builtins.isAttrs value then
        flattenCodexConfig path value
      else
        [ { inherit path value; } ]
    ) attrs);
  codexPatches = flattenCodexConfig "" codexConfig;

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
    ".agents/share/AGENTS.md".source = ./AGENTS.md;
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

  home.packages = wrapperPackages ++ [
    (pkgs.writeShellScriptBin "claude" ''exec claude.conao3 "$@"'')
    (pkgs.writeShellScriptBin "codex" ''exec codex.agent001 "$@"'')
  ];

  home.activation.ensureAgentDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatMapStringsSep "\n" (dir: "mkdir -p ${dir}") agentDirs}
  '';

  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
    settingsWarnFile="$HOME/.claude/settings-warnings.log"
    rm -f "$settingsWarnFile"
    ${lib.concatMapStringsSep "\n" (dir: ''
      settingsTarget="${dir}/settings.json"
      if [ ! -f "$settingsTarget" ] || [ -L "$settingsTarget" ]; then
        rm -f "$settingsTarget"
        echo '{}' > "$settingsTarget"
      fi
      ${lib.concatMapStringsSep "\n" applyPatch settingsPatches}
    '') claudeConfigDirs}
    ${lib.concatMapStringsSep "\n" (file: ''
      settingsTarget="${file}"
      if [ ! -f "$settingsTarget" ] || [ -L "$settingsTarget" ]; then
        rm -f "$settingsTarget"
        echo '{}' > "$settingsTarget"
      fi
      ${lib.concatMapStringsSep "\n" applyPatch mcpPatches}
    '') claudeJsonFiles}
  '';

  home.activation.agentTemplates = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
    if [ ! -f "$HOME/.agents/share/MEMORY.md" ]; then
      touch "$HOME/.agents/share/MEMORY.md"
    fi
    ${lib.concatMapStringsSep "\n" (spec: ''
      if [ ! -f "$HOME/${spec.dir}/SOUL.md" ]; then
        cp ${soulTemplate} "$HOME/${spec.dir}/SOUL.md"
      fi
      if [ ! -f "$HOME/${spec.dir}/IDENTITY.md" ]; then
        cp ${identityTemplate} "$HOME/${spec.dir}/IDENTITY.md"
      fi
      if [ ! -f "$HOME/${spec.dir}/MEMORY.md" ]; then
        touch "$HOME/${spec.dir}/MEMORY.md"
      fi
      mkdir -p "$HOME/${spec.dir}/MEMORY"
    '') wrapperSpecs}
  '';

  home.activation.agentSharedFiles = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
    ${lib.concatMapStringsSep "\n" (spec: let
      targetFile = if spec.type == "claude" then "CLAUDE.md" else "AGENTS.md";
    in ''
      ln -sf "$HOME/.agents/share/AGENTS.md" "$HOME/${spec.dir}/${targetFile}"
    '') wrapperSpecs}
  '';

  home.activation.codexMcpSettings = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
    ${lib.concatMapStringsSep "\n" (dir: ''
      mkdir -p "${dir}"
      configTarget="${dir}/config.toml"
      if [ ! -f "$configTarget" ] || [ -L "$configTarget" ]; then
        rm -f "$configTarget"
        touch "$configTarget"
      fi

      # Update MCP entries directly in TOML.
      ${lib.concatMapStringsSep "\n" (serverName:
        "${pkgs.dasel}/bin/dasel delete -f \"$configTarget\" -r toml -w toml ${lib.escapeShellArg "mcp_servers.${serverName}"} >/dev/null 2>&1 || true"
      ) codexServerNames}
      ${lib.concatMapStringsSep "\n" (patch:
        "${pkgs.dasel}/bin/dasel put -f \"$configTarget\" -r toml -w toml -t json -v ${lib.escapeShellArg (builtins.toJSON patch.value)} ${lib.escapeShellArg patch.path}"
      ) codexPatches}
    '') codexConfigDirs}
  '';

  programs.git.ignores = [
    ".claude"
    ".claude-dev"
  ];
}
