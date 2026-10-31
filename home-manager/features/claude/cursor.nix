{ pkgs, lib, ... }:
{
  programs.agents.types.cursor-agent = {
    # Cursor mcp.json: https://cursor.com/docs/context/mcp — stdio needs type + command + args; remote uses url only.
    mcp = {
      format = "cursor";
      key = "mcpServers";
      files = [ "mcp.json" ];
    };
    # Cursor profile dir == CURSOR_HOME (--user-data-dir).
    # Use overwrite (not link) so cursor-agent cannot replace the symlink with an empty file.
    files."mcp.json" = {
      scope = "instances";
      strategy = "overwrite";
    };
  };

  # Cursor GUI still needs --user-data-dir (same profile dir as cursor-agent.agent001).
  programs.agents.instances."cursor-agent.agent001".extraWrappers."cursor.agent001" =
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux
      {
        executable = lib.getExe pkgs.code-cursor-fhs;
        makeWrapperArgs = [
          "--add-flags"
          ''--user-data-dir "$CURSOR_HOME"''
        ];
      };
}
