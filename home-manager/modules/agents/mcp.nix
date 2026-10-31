{ lib }:
let
  shellWord = s: if builtins.match "[A-Za-z0-9_./~-]+" s != null then s else lib.escapeShellArg s;

  bearerHeaders =
    srv:
    lib.optionalAttrs (srv.bearerTokenEnvVar != null) {
      Authorization = "Bearer \${${srv.bearerTokenEnvVar}}";
    };

  allHeaders = srv: srv.headers // bearerHeaders srv;

  stdio =
    srv:
    {
      inherit (srv) command args;
    }
    // lib.optionalAttrs (srv.env != { }) { inherit (srv) env; };

  unsupported =
    format: name: what:
    throw "programs.agents.mcpServers.${name}: ${what} cannot be rendered for the ${format} format; remove ${format} agents from enableFor";

  renderers = {
    claude =
      name: srv:
      if srv.url != null then
        {
          type = "http";
          inherit (srv) url;
        }
        // lib.optionalAttrs (allHeaders srv != { }) { headers = allHeaders srv; }
        // lib.optionalAttrs (srv.bearerTokenFile != null) {
          headersHelper = "printf '{\"Authorization\":\"Bearer %s\"}' \"$(tr -d ' \\t\\r\\n' < ${shellWord srv.bearerTokenFile})\"";
        }
      else
        { type = "stdio"; } // stdio srv;

    codex =
      name: srv:
      if srv.bearerTokenFile != null then
        unsupported "codex" name "bearerTokenFile"
      else if srv.url != null then
        {
          type = "http";
          inherit (srv) url;
        }
        // lib.optionalAttrs (srv.bearerTokenEnvVar != null) {
          bearer_token_env_var = srv.bearerTokenEnvVar;
        }
        // lib.optionalAttrs (srv.headers != { }) { http_headers = srv.headers; }
      else
        stdio srv;

    cursor =
      name: srv:
      if srv.bearerTokenFile != null then
        unsupported "cursor" name "bearerTokenFile"
      else if srv.url != null then
        { inherit (srv) url; } // lib.optionalAttrs (allHeaders srv != { }) { headers = allHeaders srv; }
      else
        { type = "stdio"; } // stdio srv;
  };
in
{
  render =
    { format, typeName }:
    servers:
    lib.mapAttrs renderers.${format} (
      lib.filterAttrs (_: srv: builtins.elem typeName srv.enableFor) servers
    );
}
