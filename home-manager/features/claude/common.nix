{
  pkgs,
  lib,
  inputs,
  system,
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
  claudeBin = "${inputs.nix-claude-code.packages.${system}.default}/bin/claude";
  codexBin = "${llmAgents.codex}/bin/codex";
  piBin = "${llmAgents.pi}/bin/pi";
  cursorAgentPkg = llmAgents.cursor-agent;
  cursorExe = lib.getExe ((pkgs.callPackage ../../../pkgs/code-cursor.nix { }).fhs);
  agentExe = lib.getExe cursorAgentPkg;

  aliasSpecs = [
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

  sakanaProfilePackages = [
    (pkgs.writeShellScriptBin "codex.sakana.agent001" ''
      export CODEX_HOME="$HOME/.agents/.codex.agent001"
      exec ${codexBin} -p fugu "$@"
    '')
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
    "claude.recerqa"
    "claude.agent001"
    "claude.agent002"
    "claude.agent003"
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
  agentInstructionFileEntries = [
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

  mcpServers = {
    linear = {
      type = "http";
      url = "https://mcp.linear.app/mcp";
    };
    penpot = {
      type = "http";
      url = "https://design.penpot.app/mcp/stream?userToken=\${PENPOT_MCP_KEY}";
    };
    devin = {
      type = "http";
      url = "https://mcp.devin.ai/mcp";
      headers = {
        Authorization = "Bearer \${DEVIN_API_KEY}";
      };
    };
  };
in
{
  inherit
    llmAgents
    claudeBin
    aliasSpecs
    wrapperSpecs
    wrapperPackages
    cursorProfilePackages
    sakanaProfilePackages
    agentDirs
    claudeSharedDir
    claudeSpecDirs
    claudeConfigDirs
    codexSharedDir
    codexSpecDirs
    codexConfigDirs
    claudeJsonFiles
    agentInstructionFileEntries
    mcpServers
    ;
}
