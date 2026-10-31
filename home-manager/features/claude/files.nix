{ config, ... }:
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
            command = config.programs.agents.types.claude.executable;
            args = [
              "mcp"
              "serve"
            ];
          };
        };
      };
    };
  };
}
