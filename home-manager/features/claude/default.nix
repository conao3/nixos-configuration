{
  config,
  pkgs,
  lib,
  inputs,
  system,
  ...
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
  claudeBin = "${inputs.nix-claude-code.packages.${system}.default}/bin/claude";
  codexBin = "${llmAgents.codex}/bin/codex";
  piBin = "${llmAgents.pi}/bin/pi";
  cursorAgentPkg = llmAgents.cursor-agent;
  cursorExe = lib.getExe ((pkgs.callPackage ../../../pkgs/code-cursor.nix { }).fhs);
  agentExe = lib.getExe cursorAgentPkg;

  pencilMcpServer = "${
    pkgs.appimageTools.extractType2 {
      pname = "pencil-dev";
      version = "2025.1.0";
      src = pkgs.fetchurl {
        url = "https://www.pencil.dev/download/Pencil-linux-x86_64.AppImage";
        hash = "sha256-31gqv4kU8LB2e84MQKcNYXTLNSeJLzmWQahz6+bi2jk=";
      };
    }
  }/resources/app.asar.unpacked/out/mcp-server-linux-x64";

  aliasSpecs = [
    {
      executableName = "claude";
      target = "claude.agent001";
    }
    {
      executableName = "codex";
      target = "codex.agent001";
    }
    {
      executableName = "cursor";
      target = "cursor.agent001";
    }
    {
      executableName = "cursor-agent";
      target = "cursor-agent.agent001";
    }
    {
      executableName = "pi";
      target = "pi.agent001";
    }
  ];

  mkSpec =
    name:
    let
      type = builtins.head (lib.splitString "." name);
    in
    {
      inherit name type;
      bin =
        if type == "claude" then
          claudeBin
        else if type == "codex" then
          codexBin
        else if type == "pi" then
          piBin
        else if type == "cursor-agent" then
          agentExe
        else
          throw "claude/default.nix mkSpec: unknown agent type '${type}' in '${name}'";
      envKey =
        if type == "claude" then
          "CLAUDE_CONFIG_DIR"
        else if type == "codex" then
          "CODEX_HOME"
        else if type == "pi" then
          "PI_CODING_AGENT_DIR"
        else if type == "cursor-agent" then
          "CURSOR_HOME"
        else
          throw "claude/default.nix mkSpec: unknown agent type '${type}'";
      dir = ".agents/.${name}";
    };

  wrapperSpecs = map mkSpec [
    "claude.conao3"
    "claude.toyokumo"
    "claude.agent001"
    "claude.agent002"
    "claude.yui"
    "claude.worker"
    "codex.conao3"
    "codex.agent001"
    "codex.agent002"
    "codex.worker"
    "pi.agent001"
    "pi.agent002"
    "cursor-agent.agent001"
  ];

  mkWrapper =
    spec:
    pkgs.runCommand spec.name { buildInputs = [ pkgs.makeWrapper ]; } ''
      makeWrapper ${spec.bin} $out/bin/${spec.name} \
        --run 'export ${spec.envKey}="$HOME/${spec.dir}"'
    '';

  # Cursor GUI still needs --user-data-dir (same profile dir as cursor-agent.agent001).
  cursorProfileBody = ''
    export CURSOR_HOME="$HOME/.agents/.cursor-agent.agent001"
    exec ${cursorExe} --user-data-dir "$HOME/.agents/.cursor-agent.agent001" "$@"
  '';
  cursorProfilePackages = lib.optionals pkgs.stdenv.isLinux [
    (pkgs.writeShellScriptBin "cursor.agent001" cursorProfileBody)
  ];

  statusLineScript = pkgs.writeShellScript "claude-statusline" ''
    set -euo pipefail -o posix
    input="$(${pkgs.coreutils}/bin/cat)"
    email="$(${pkgs.jq}/bin/jq -r '.oauthAccount.emailAddress // empty' "''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.claude.json" 2>/dev/null || true)"
    model="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // empty')"
    dir="$(printf '%s' "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir // .cwd // empty')"
    printf '%s | %s | %s' "$email" "$model" "$(${pkgs.coreutils}/bin/basename "$dir")"
  '';

  soulTemplate = pkgs.writeText "SOUL.md" (builtins.readFile ./SOUL.md);
  identityTemplate = pkgs.writeText "IDENTITY.md" (builtins.readFile ./IDENTITY.md);
  agentsTemplate = ./AGENTS.md;
  agentsWorkerTemplate = ./AGENTS-worker.md;

  wrapperPackages = map mkWrapper wrapperSpecs;
  agentDirs = [
    "$HOME/.agents"
    "$HOME/.agents/share"
    claudeSharedDir
    codexSharedDir
  ]
  ++ map (spec: "$HOME/${spec.dir}") wrapperSpecs;
  claudeSharedDir = "$HOME/.agents/.claude";
  claudeSpecs = builtins.filter (spec: spec.type == "claude") wrapperSpecs;
  claudeSpecDirs = map (spec: "$HOME/${spec.dir}") (
    builtins.filter (spec: !(lib.hasSuffix ".worker" spec.name)) (
      (builtins.filter (spec: spec.name == "claude.agent001") claudeSpecs)
      ++ (builtins.filter (spec: spec.name != "claude.agent001") claudeSpecs)
    )
  );
  claudeConfigDirs = [
    "$HOME/.claude"
    claudeSharedDir
  ];
  codexSharedDir = "$HOME/.agents/.codex";
  codexSpecs = builtins.filter (spec: spec.type == "codex") wrapperSpecs;
  codexSpecDirs = map (spec: "$HOME/${spec.dir}") (
    builtins.filter (spec: !(lib.hasSuffix ".worker" spec.name)) (
      (builtins.filter (spec: spec.name == "codex.agent001") codexSpecs)
      ++ (builtins.filter (spec: spec.name != "codex.agent001") codexSpecs)
    )
  );
  codexConfigDirs = [
    "$HOME/.codex"
    codexSharedDir
  ];
  claudeJsonFiles = [
    "$HOME/.claude.json"
  ]
  ++ map (spec: "$HOME/${spec.dir}/.claude.json") (
    builtins.filter (spec: spec.type == "claude") wrapperSpecs
  );
  agentInstructionFileEntries =
    [
      {
        name = ".agents/share/AGENTS.md";
        template = agentsTemplate;
      }
      {
        name = "${lib.removePrefix "$HOME/" claudeSharedDir}/CLAUDE.md";
        template = agentsTemplate;
      }
      {
        name = "${lib.removePrefix "$HOME/" codexSharedDir}/AGENTS.md";
        template = agentsTemplate;
      }
    ]
    ++ map (spec: {
      name = "${spec.dir}/AGENTS.md";
      template = agentsTemplate;
    }) (builtins.filter (spec: spec.type != "claude" && spec.type != "codex") wrapperSpecs)
    ++ [
      {
        name = ".agents/.claude.worker/CLAUDE.md";
        template = agentsWorkerTemplate;
      }
      {
        name = ".agents/.codex.worker/AGENTS.md";
        template = agentsWorkerTemplate;
      }
    ];

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
    autoMemoryEnabled = false;
    autoMemoryDirectory = "~/.agents/share/auto-memory";
    statusLine = {
      type = "command";
      command = "${statusLineScript}";
    };
  };

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

  mcpServers = {
    linear = {
      type = "http";
      url = "https://mcp.linear.app/mcp";
    };
    penpot = {
      type = "http";
      url = "http://localhost:4401/mcp";
    };
  }
  // {
    devin = {
      type = "http";
      url = "https://mcp.devin.ai/mcp";
      headers = {
        Authorization = "Bearer \${DEVIN_API_KEY}";
      };
    };
  }
  // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
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

  # Cursor mcp.json: https://cursor.com/docs/context/mcp — stdio needs type + command + args; remote uses url only.
  cursorMcpServers = lib.mapAttrs (
    _: srv:
    if srv ? url then
      {
        inherit (srv) url;
      }
      // lib.optionalAttrs (srv ? headers) { inherit (srv) headers; }
    else
      {
        type = "stdio";
        command = srv.command;
        args = srv.args or [ ];
      }
      // lib.optionalAttrs (srv ? env) { inherit (srv) env; }
  ) mcpServers;

  codexMcpServers = lib.mapAttrs (
    _: srv:
    let
      usesDevinEnvBearer =
        lib.hasAttrByPath [ "headers" "Authorization" ] srv
        && srv.headers.Authorization == "Bearer \${DEVIN_API_KEY}";
    in
    if srv ? url then
      {
        type = "http";
        inherit (srv) url;
      }
      // lib.optionalAttrs usesDevinEnvBearer {
        bearer_token_env_var = "DEVIN_API_KEY";
      }
    else
      {
        command = srv.command;
        args = srv.args or [ ];
      }
      // lib.optionalAttrs (srv ? env) { inherit (srv) env; }
  ) mcpServers;

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

  mkShareReconcile =
    {
      sharedDir,
      specDirs,
      backupPrefix,
      excludeNames,
      historyKey,
      forceLinks,
      discardNames,
    }:
    let
      excludeCase = lib.concatStringsSep " | " excludeNames;
      discardCond =
        if discardNames == [ ] then
          "false"
        else
          lib.concatMapStringsSep " || " (n: ''[ "$e" = "${n}" ]'') discardNames;
    in
    ''
      shared="${sharedDir}"
      mkdir -p "$shared"
      backupRoot="$HOME/.agents/${backupPrefix}.backup-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
      profiles=(${lib.concatStringsSep " " (map (d: "\"" + d + "\"") specDirs)})
      shopt -s dotglob nullglob
      for p in "''${profiles[@]}"; do
        [ -d "$p" ] || continue
        for path in "$p"/*; do
          e="$(${pkgs.coreutils}/bin/basename "$path")"
          case "$e" in
            ${excludeCase}) continue ;;
          esac
          target="$shared/$e"
          if [ -L "$path" ]; then
            ${pkgs.coreutils}/bin/ln -sfn "$target" "$path"
            continue
          fi
          if [ -d "$path" ]; then
            if [ ! -e "$target" ]; then
              ${pkgs.coreutils}/bin/mv "$path" "$target"
            else
              ${pkgs.coreutils}/bin/cp -anl "$path/." "$target/" 2>/dev/null \
                || ${pkgs.coreutils}/bin/cp -an "$path/." "$target/" 2>/dev/null || true
              ${pkgs.coreutils}/bin/rm -rf "$path"
            fi
          else
            bdir="$backupRoot/$(${pkgs.coreutils}/bin/basename "$p")"
            mkdir -p "$bdir"
            ${pkgs.coreutils}/bin/cp -a "$path" "$bdir/" 2>/dev/null || true
            if [ "$e" = "history.jsonl" ]; then
              tmp="$target.merge.$$"
              if [ -e "$target" ]; then
                ${pkgs.coreutils}/bin/cat "$target" "$path"
              else
                ${pkgs.coreutils}/bin/cat "$path"
              fi \
                | ${pkgs.jq}/bin/jq -sc 'map(select(type=="object")) | unique | sort_by(${historyKey} // 0) | .[]' \
                > "$tmp" 2>/dev/null || ${pkgs.coreutils}/bin/cp "$path" "$tmp"
              ${pkgs.coreutils}/bin/mv "$tmp" "$target"
              ${pkgs.coreutils}/bin/rm -f "$path"
            else
              case "$e" in
                *.sqlite | *.sqlite-shm | *.sqlite-wal)
                  if [ ! -e "$target" ]; then
                    ${pkgs.coreutils}/bin/mv "$path" "$target"
                  else
                    ${pkgs.coreutils}/bin/rm -f "$path"
                  fi
                  ;;
                *)
                  if ${discardCond}; then
                    ${pkgs.coreutils}/bin/rm -f "$path"
                  elif [ ! -e "$target" ]; then
                    ${pkgs.coreutils}/bin/mv "$path" "$target"
                  elif [ "$path" -nt "$target" ]; then
                    ${pkgs.coreutils}/bin/cp -a "$path" "$target"
                    ${pkgs.coreutils}/bin/rm -f "$path"
                else
                  ${pkgs.coreutils}/bin/rm -f "$path"
                fi
                ;;
            esac
            fi
          fi
          ${pkgs.coreutils}/bin/ln -sfn "$target" "$path"
        done
        for req in ${lib.concatStringsSep " " forceLinks}; do
          ${pkgs.coreutils}/bin/ln -sfn "$shared/$req" "$p/$req"
        done
        for spath in "$shared"/*; do
          se="$(${pkgs.coreutils}/bin/basename "$spath")"
          case "$se" in
            ${excludeCase}) continue ;;
          esac
          if [ ! -e "$p/$se" ] && [ ! -L "$p/$se" ]; then
            ${pkgs.coreutils}/bin/ln -sfn "$spath" "$p/$se"
          fi
        done
      done
    '';
in
{
  home.file =
    {
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
    }
    // builtins.listToAttrs (
      map (entry: {
        name = entry.name;
        value = {
          source = entry.template;
        };
      }) agentInstructionFileEntries
    );

  home.packages =
    wrapperPackages
    ++ cursorProfilePackages
    ++ map (spec: pkgs.writeShellScriptBin spec.executableName ''exec ${spec.target} "$@"'') aliasSpecs;

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
      ${applyMcpServers}
      ${lib.concatMapStringsSep "\n" applyPatch settingsPatches}
      ${applyHooks}
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

  home.activation.claudeShareReconcile =
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "ensureAgentDirs"
        "agentInstructions"
        "claudeSettings"
      ]
      (mkShareReconcile {
        sharedDir = claudeSharedDir;
        specDirs = claudeSpecDirs;
        backupPrefix = ".claude";
        excludeNames = [
          ".claude.json"
          ".credentials.json"
        ];
        historyKey = ".timestamp";
        forceLinks = [
          "settings.json"
          "CLAUDE.md"
        ];
        discardNames = [
          "settings.json"
          "CLAUDE.md"
        ];
      });

  home.activation.codexShareReconcile =
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "ensureAgentDirs"
        "agentInstructions"
      ]
      (mkShareReconcile {
        sharedDir = codexSharedDir;
        specDirs = codexSpecDirs;
        backupPrefix = ".codex";
        excludeNames = [ "auth.json" ];
        historyKey = ".ts";
        forceLinks = [
          "config.toml"
          "AGENTS.md"
        ];
        discardNames = [ "AGENTS.md" ];
      });

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

  home.activation.codexMcpSettings =
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "ensureAgentDirs"
        "codexShareReconcile"
      ]
      (
    let
      codexFeatures = {
        goals = true;
      };
      codexBaseJson = builtins.toJSON {
        mcp_servers = codexMcpServers;
        features = codexFeatures;
      };
    in
    ''
      ${lib.concatMapStringsSep "\n" (dir: ''
        mkdir -p "${dir}"
        configTarget="${dir}/config.toml"
        if [ ! -f "$configTarget" ] || [ -L "$configTarget" ] || [ ! -s "$configTarget" ]; then
          rm -f "$configTarget"
          echo '${codexBaseJson}' | ${pkgs.remarshal}/bin/remarshal -f json -t toml > "$configTarget"
        else
          ${pkgs.yq-go}/bin/yq -p toml -o json "$configTarget" \
            | ${pkgs.jq}/bin/jq \
                --argjson servers '${builtins.toJSON codexMcpServers}' \
                --argjson features '${builtins.toJSON codexFeatures}' \
                '.mcp_servers = $servers | .features = $features' \
            | ${pkgs.remarshal}/bin/remarshal -f json -t toml > "$configTarget.tmp" \
            && mv "$configTarget.tmp" "$configTarget"
        fi
      '') codexConfigDirs}
    ''
  );

  # Same MCP servers as Claude/Codex; Cursor profile dir == CURSOR_HOME (--user-data-dir).
  # Use activation (not home.file) so cursor-agent cannot replace the symlink with an empty file.
  home.activation.cursorMcpSettings = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] (
    let
      cursorMcpJson = builtins.toJSON { mcpServers = cursorMcpServers; };
    in
    ''
      configTarget="$HOME/.agents/.cursor-agent.agent001/mcp.json"
      rm -f "$configTarget"
      echo '${cursorMcpJson}' > "$configTarget"
    ''
  );

  programs.git.ignores = [
    ".claude"
    ".claude-dev"
  ];
}
