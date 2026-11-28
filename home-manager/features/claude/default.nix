{
  config,
  pkgs,
  inputs,
  system,
  ...
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
  codexPackage = pkgs.callPackage ../../../pkgs/codex.nix { fallbackPackage = llmAgents.codex; };
  withBashShell =
    name: executable:
    "${pkgs.writeShellScript "${name}-bash-shell" ''
      export SHELL=${pkgs.bashInteractive}/bin/bash
      exec ${executable} "$@"
    ''}";
  opencodeWrapperArgs = [
    "--run"
    ''export OPENCODE_DB="$OPENCODE_CONFIG_DIR/opencode.db" XDG_STATE_HOME="$OPENCODE_CONFIG_DIR/state"''
  ];
in
{
  imports = [
    inputs.nix-agents.homeManagerModules.default
    ./agmsg.nix
    ./ci-wait.nix
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
        package = pkgs.callPackage ../../../pkgs/yolo-flag.nix { } {
          package = inputs.nix-claude-code.packages.${system}.default;
          flags = [ "--dangerously-skip-permissions" ];
        };
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
            "seed-admin"
          ];
          discard = [ "settings.json" ];
        };
      };
      codex = {
        package = codexPackage;
        envVar = "CODEX_HOME";
        homeDir = ".codex";
        share = {
          enable = true;
          exclude = [ "auth.json" ];
          history.sortKey = ".ts";
        };
      };
      opencode = {
        executable = withBashShell "opencode2" "${llmAgents.opencode2}/bin/opencode2";
        envVar = "OPENCODE_CONFIG_DIR";
        homeDir = ".config/opencode";
        share = {
          enable = true;
          exclude = [
            "opencode.db*"
            "state"
            "service*.json"
          ];
        };
        files."AGENTS.md" = {
          strategy = "link";
          source = ./AGENTS.md;
        };
      };
      pi = {
        executable = "${llmAgents.pi}/bin/pi";
        envVar = "PI_CODING_AGENT_DIR";
      };
      cursor-agent = {
        executable = withBashShell "cursor-agent" (pkgs.lib.getExe llmAgents.cursor-agent);
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
      "codex.conao3" = { };
      "codex.agent001" = { };
      "codex.agent002" = { };
      "opencode.agent001".wrapper.makeWrapperArgs = opencodeWrapperArgs;
      "pi.agent001" = { };
      "pi.agent002" = { };
      "cursor-agent.agent001" = { };
    };

    aliases = {
      cursor = "cursor.agent001";
      cursor-agent = "cursor-agent.agent001";
      opencode = "opencode.agent001";
      pi = "pi.agent001";
    };
  };

  home.file =
    let
      devinHome = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/.devin.conao3";
    in
    {
      ".agents/.devin.conao3/AGENTS.md".source = ./AGENTS.md;
      ".devin/global_rules.md".source = ./devin-global-rules.md;
      ".config/devin".source = devinHome;
      ".local/share/devin".source = devinHome;
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
