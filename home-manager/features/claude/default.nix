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

  programs.git.ignores = [
    ".claude"
    ".claude-dev"
  ];
}
