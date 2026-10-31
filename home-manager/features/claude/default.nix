{
  pkgs,
  inputs,
  system,
  ...
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
in
{
  imports = [
    ../../modules/agents
    ./agmsg.nix
    ./codex.nix
    ./cursor.nix
    ./files.nix
    ./mcp.nix
    ./settings.nix
  ];

  programs.agents = {
    enable = true;
    instructions = ./AGENTS.md;
    common = {
      ensureFiles = [ "MEMORY.md" ];
      directories = [
        "MEMORY_SUGGEST"
        "projects"
        "notes"
      ];
    };
    warningsFile = ".claude/settings-warnings.log";

    types = {
      claude = {
        package = inputs.nix-claude-code.packages.${system}.default;
        envVar = "CLAUDE_CONFIG_DIR";
        homeDir = ".claude";
        instructionsFile = "CLAUDE.md";
        share = {
          enable = true;
          exclude = [
            ".claude.json"
            ".claude.json.tmp"
            ".claude.json.*"
            ".credentials.json"
          ];
          discard = [ "settings.json" ];
        };
      };
      codex = {
        package = llmAgents.codex;
        envVar = "CODEX_HOME";
        homeDir = ".codex";
        share = {
          enable = true;
          exclude = [ "auth.json" ];
          history.sortKey = ".ts";
        };
      };
      pi = {
        executable = "${llmAgents.pi}/bin/pi";
        envVar = "PI_CODING_AGENT_DIR";
      };
      cursor-agent = {
        executable = pkgs.lib.getExe llmAgents.cursor-agent;
        envVar = "CURSOR_HOME";
      };
    };

    instances = {
      "claude.conao3" = { };
      "claude.toyokumo" = { };
      "claude.recerqa" = { };
      "claude.agent001" = { };
      "claude.agent002" = { };
      "claude.agent003" = { };
      "claude.yui" = { };
      "claude.worker" = {
        share = false;
        instructions = ./AGENTS-worker.md;
      };
      "codex.conao3" = { };
      "codex.agent001" = { };
      "codex.agent002" = { };
      "codex.worker" = {
        share = false;
        instructions = ./AGENTS-worker.md;
      };
      "pi.agent001" = { };
      "pi.agent002" = { };
      "cursor-agent.agent001" = { };
    };

    aliases = {
      cursor = "cursor.agent001";
      cursor-agent = "cursor-agent.agent001";
      pi = "pi.agent001";
    };
  };

  home.packages = [
    # Claude Code の音声入力 (/voice) が録音に使う (`rec` コマンド)。無いと「Voice mode requires SoX」で有効化できない
    pkgs.sox
  ];

  programs.git.ignores = [
    ".claude"
    ".claude-dev"
    ".codex"
  ];
}
