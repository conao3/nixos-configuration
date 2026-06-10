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
    codexConfigDirs
    mcpServers
    ;

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
in
{
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
}
