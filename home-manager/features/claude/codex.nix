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
    codexSpecDirs
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
  fuguCatalog = ./fugu/fugu.json;
  fuguProvider = {
    name = "Sakana API";
    base_url = "https://api.sakana.ai/v1";
    env_key = "SAKANA_API_KEY";
    wire_api = "responses";
    stream_idle_timeout_ms = 7200000;
    stream_max_retries = 5;
    request_max_retries = 4;
  };
  fuguProfile = {
    model = "fugu";
    model_reasoning_effort = "high";
    model_provider = "sakana";
    features = {
      image_generation = false;
      apps = false;
    };
  };
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
          codexStatusLine = [
            "thread-title"
            "model-with-reasoning"
            "context-remaining"
            "current-dir"
          ];
          codexBaseJson = builtins.toJSON {
            mcp_servers = codexMcpServers;
            features = codexFeatures;
            model_providers.sakana = fuguProvider;
            tui.status_line = codexStatusLine;
          };
        in
        ''
          ${lib.concatMapStringsSep "\n" (dir: ''
            mkdir -p "${dir}"
            install -m 0644 ${fuguCatalog} "${dir}/fugu.json"
            fuguProfileTarget="${dir}/fugu.config.toml"
            echo '${builtins.toJSON fuguProfile}' \
              | ${pkgs.jq}/bin/jq --arg dir "${dir}" '. + {model_catalog_json: ($dir + "/fugu.json")}' \
              | ${pkgs.remarshal}/bin/remarshal -f json -t toml > "$fuguProfileTarget"
            configTarget="${dir}/config.toml"
            if [ ! -f "$configTarget" ] || [ -L "$configTarget" ] || [ ! -s "$configTarget" ]; then
              rm -f "$configTarget"
              echo '${codexBaseJson}' | ${pkgs.remarshal}/bin/remarshal -f json -t toml > "$configTarget"
            else
              ${pkgs.yq-go}/bin/yq -p toml -o json "$configTarget" \
                | ${pkgs.jq}/bin/jq \
                    --argjson servers '${builtins.toJSON codexMcpServers}' \
                    --argjson features '${builtins.toJSON codexFeatures}' \
                    --argjson provider '${builtins.toJSON fuguProvider}' \
                    --argjson statusLine '${builtins.toJSON codexStatusLine}' \
                    'del(.profiles.fugu)
                     | .mcp_servers = $servers
                     | .features = $features
                     | .model_providers.sakana = $provider
                     | .tui.status_line = $statusLine' \
                | ${pkgs.remarshal}/bin/remarshal -f json -t toml > "$configTarget.tmp" \
                && mv "$configTarget.tmp" "$configTarget"
            fi
          '') codexConfigDirs}
          ${lib.concatMapStringsSep "\n" (dir: ''
            if [ -d "${dir}" ]; then
              for f in fugu.config.toml fugu.json; do
                target="$HOME/.agents/.codex/$f"
                link="${dir}/$f"
                if [ -e "$target" ] && { [ ! -e "$link" ] || [ -L "$link" ]; }; then
                  ln -sfn "$target" "$link"
                fi
              done
            fi
          '') codexSpecDirs}
        ''
      );
}
