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
    claudeBin
    agentInstructionFileEntries
    ;
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
  }
  // builtins.listToAttrs (
    map (entry: {
      name = entry.name;
      value = {
        source = entry.template;
      };
    }) agentInstructionFileEntries
  );
}
