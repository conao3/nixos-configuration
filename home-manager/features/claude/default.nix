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
  pencilMcpServer = "${pkgs.appimageTools.extractType2 {
    pname = "pencil-dev";
    version = "2025.1.0";
    src = pkgs.fetchurl {
      url = "https://www.pencil.dev/download/Pencil-linux-x86_64.AppImage";
      hash = "sha256-31gqv4kU8LB2e84MQKcNYXTLNSeJLzmWQahz6+bi2jk=";
    };
  }}/resources/app.asar.unpacked/out/mcp-server-linux-x64";

  aliasSpecs = [
    {
      executableName = "claude";
      target = "claude.agent001";
    }
    {
      executableName = "codex";
      target = "codex.agent001";
    }
  ];
 
  mkSpec = name: let
    type = builtins.head (lib.splitString "." name);
  in {
    inherit name type;
    bin = if type == "claude" then claudeBin else codexBin;
    envKey = if type == "claude" then "CLAUDE_CONFIG_DIR" else "CODEX_HOME";
    dir = ".agents/.${name}";
  };

  wrapperSpecs = map mkSpec [
    "claude.conao3"
    "claude.toyokumo"
    "claude.agent001"
    "claude.yui"
    "codex.conao3"
    "codex.agent001"
    "codex.agent002"
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

  mcpServers = {
    chrome_devtools = {
      command = "npx";
      args = [
        "-y"
        "chrome-devtools-mcp@latest"
        "--browserUrl"
        "http://127.0.0.1:15123"
      ];
    };
    deepwiki = {
      type = "http";
      url = "https://mcp.deepwiki.com/mcp";
    };
    linear = {
      type = "http";
      url = "https://mcp.linear.app/mcp";
    };
  } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
    pencil = {
      command = "bash";
      args = [
        "-c"
        ''
          set -euo pipefail; pbin=/etc/profiles/per-user/conao/bin/pencil-dev; init=$(grep -o "/nix/store/[^ ]*-init" "$(readlink -f "$pbin")" | head -n1); appdir=$(grep -o "/nix/store/[^ ]*-extracted" "$init" | head -n1); exec steam-run "$appdir/resources/app.asar.unpacked/out/mcp-server-linux-x64" --app desktop
        ''
      ];
    };
  };

  settingsPatches = flattenSettings "" claudeSettings;

  applyPatch = patch: let
    fromJson = builtins.toJSON patch.from;
    toJson = builtins.toJSON patch.to;
  in ''
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

  applyMcpServer = name: server: let
    serverJson = builtins.toJSON server;
  in ''
    ${pkgs.jq}/bin/jq --argjson server '${serverJson}' '.mcpServers.${name} = $server' \
      "$settingsTarget" > "$settingsTarget.tmp" && mv "$settingsTarget.tmp" "$settingsTarget"
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
  } // lib.listToAttrs (map (spec: {
    name = "${spec.dir}/${if spec.type == "claude" then "CLAUDE.md" else "AGENTS.md"}";
    value.source = ./AGENTS.md;
  }) wrapperSpecs);

  home.packages = wrapperPackages ++ map (spec:
    pkgs.writeShellScriptBin spec.executableName ''exec ${spec.target} "$@"''
  ) aliasSpecs;

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
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList applyMcpServer mcpServers)}
    '') claudeJsonFiles}
  '';

  # MEMORYない方が良いのではという疑惑。エージェントレベルは無効化する。
  # home.activation.agentTemplates = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
  #   if [ ! -f "$HOME/.agents/share/MEMORY.md" ]; then
  #     touch "$HOME/.agents/share/MEMORY.md"
  #   fi
  #   ${lib.concatMapStringsSep "\n" (spec: ''
  #     if [ ! -f "$HOME/${spec.dir}/SOUL.md" ]; then
  #       ${pkgs.coreutils}/bin/install -m 644 ${soulTemplate} "$HOME/${spec.dir}/SOUL.md"
  #     fi
  #     if [ ! -f "$HOME/${spec.dir}/IDENTITY.md" ]; then
  #       ${pkgs.coreutils}/bin/install -m 644 ${identityTemplate} "$HOME/${spec.dir}/IDENTITY.md"
  #     fi
  #     if [ ! -f "$HOME/${spec.dir}/MEMORY.md" ]; then
  #       touch "$HOME/${spec.dir}/MEMORY.md"
  #     fi
  #     mkdir -p "$HOME/${spec.dir}/MEMORY"
  #   '') wrapperSpecs}
  # '';

  home.activation.agentTemplates = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
    if [ ! -f "$HOME/.agents/share/MEMORY.md" ]; then
      touch "$HOME/.agents/share/MEMORY.md"
    fi
    mkdir -p "$HOME"/.agents/share/MEMORY_SUGGEST
    mkdir -p "$HOME"/.agents/share/projects
    mkdir -p "$HOME"/.agents/share/notes
  '';

  home.activation.codexMcpSettings = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] (let
    codexServerNames = builtins.attrNames mcpServers;
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
    codexPatches = flattenCodexConfig "" { mcp_servers = mcpServers; };
  in ''
    ${lib.concatMapStringsSep "\n" (dir: ''
      mkdir -p "${dir}"
      configTarget="${dir}/config.toml"
      if [ ! -f "$configTarget" ] || [ -L "$configTarget" ]; then
        rm -f "$configTarget"
        touch "$configTarget"
      fi

      ${lib.concatMapStringsSep "\n" (serverName:
        "${pkgs.dasel}/bin/dasel delete -f \"$configTarget\" -r toml -w toml ${lib.escapeShellArg "mcp_servers.${serverName}"} >/dev/null 2>&1 || true"
      ) codexServerNames}
      ${lib.concatMapStringsSep "\n" (patch:
        "${pkgs.dasel}/bin/dasel put -f \"$configTarget\" -r toml -w toml -t json -v ${lib.escapeShellArg (builtins.toJSON patch.value)} ${lib.escapeShellArg patch.path}"
      ) codexPatches}
    '') codexConfigDirs}
  '');

  programs.git.ignores = [
    ".claude"
    ".claude-dev"
  ];
}
