{
  pkgs,
  inputs,
  system,
  agentsLib,
  ...
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
  fuguProvider = {
    name = "Sakana API";
    base_url = "https://api.sakana.ai/v1";
    env_key = "SAKANA_API_KEY";
    wire_api = "responses";
    stream_idle_timeout_ms = 7200000;
    stream_max_retries = 5;
    request_max_retries = 4;
  };
in
{
  programs.agents.types.codex = {
    # codex 0.158 の TUI は常駐 app-server daemon を要求するが、nix package は
    # standalone installer 形式ではないため起動に失敗する。対話起動と resume / fork には
    # --no-daemon を足す (exec など他のサブコマンドはこの flag を受け付けない)。
    executable = "${pkgs.writeShellScript "codex-no-daemon" ''
      real=${llmAgents.codex}/bin/codex
      case "''${1-}" in
        "" | -*) exec "$real" --no-daemon "$@" ;;
        resume | fork)
          sub=$1
          shift
          exec "$real" "$sub" --no-daemon "$@"
          ;;
        *) exec "$real" "$@" ;;
      esac
    ''}";
    mcp = {
      format = "codex";
      key = "mcp_servers";
      files = [ "config.toml" ];
    };
    files = {
      "config.toml" = {
        onConflict = "overwrite";
        settings = {
          approval_policy = "never";
          sandbox_mode = "danger-full-access";
          features = agentsLib.force { goals = true; };
          model_providers.sakana = agentsLib.force fuguProvider;
          tui.status_line = [
            "thread-title"
            "model-with-reasoning"
            "context-remaining"
            "current-dir"
          ];
          profiles.fugu = agentsLib.delete;
        };
      };
      "fugu.json" = {
        strategy = "overwrite";
        source = ./fugu/fugu.json;
      };
      "fugu.config.toml" = {
        strategy = "overwrite";
        settings =
          { dir }:
          {
            model = "fugu";
            model_reasoning_effort = "high";
            model_provider = "sakana";
            model_catalog_json = "${dir}/fugu.json";
            features = {
              image_generation = false;
              apps = false;
            };
          };
      };
    };
  };

  programs.agents.instances."codex.agent001".extraWrappers."codex.sakana.agent001".makeWrapperArgs = [
    "--add-flags"
    "-p fugu"
  ];
}
