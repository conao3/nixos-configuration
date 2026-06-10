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
    mcpServers
    ;

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
in
{
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
}
