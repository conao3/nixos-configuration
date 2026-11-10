{
  config,
  inputs,
  lib,
  osConfig ? null,
  pkgs,
  system,
  ...
}:
let
  t3codePackages = import ../../pkgs/t3code.nix { inherit inputs system; };
  isEos =
    pkgs.stdenv.hostPlatform.isLinux
    && osConfig != null
    && osConfig.networking.hostName == "conao-nixos-eos";

  hostName = osConfig.networking.hostName;

  threadTitleInstructions = "タイトルは日本語で書き、末尾に半角スペースと分類のタグを 1 つだけ付ける (例: 「トロントの住居探し #住居」)。タグは # に続く 1 語で、作業の領域を表す (例: #求職 #会計 #住居 #英語 #ルーチン #t3code #nixos)。前のタイトルのタグが今の作業に合っていれば、同じタグを使う。";

  t3ThreadRetitle = pkgs.writeShellApplication {
    name = "t3-thread-retitle";
    runtimeInputs = [
      t3codePackages.t3code
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      project=$HOME/ghq/github.com/conao3/idea
      state_dir=''${XDG_STATE_HOME:-$HOME/.local/state}/t3-thread-retitle
      state=$state_dir/latest-runs.json
      mkdir -p "$state_dir"
      [ -s "$state" ] || echo '{}' > "$state"
      threads=$(t3 thread list --project "$project" --json)
      ids=$(jq -r --slurpfile seen "$state" '
        .[]
        | select(.latestRunId != null)
        | select(.settled | not)
        | select(.status | IN("running", "waiting", "queued", "starting", "preparing") | not)
        | select($seen[0][.threadId] != .latestRunId)
        | .threadId
      ' <<<"$threads")
      while IFS= read -r id; do
        [ -n "$id" ] || continue
        if t3 thread retitle "$id" </dev/null >/dev/null; then
          run=$(jq -r --arg id "$id" '.[] | select(.threadId == $id) | .latestRunId' <<<"$threads")
          tmp=$(mktemp "$state_dir/.latest-runs.XXXXXX")
          jq --arg id "$id" --arg run "$run" '.[$id] = $run' "$state" > "$tmp"
          mv -T "$tmp" "$state"
        fi
      done <<<"$ids"
    '';
  };

  claudeLaunchArgs = "--append-system-prompt-file /home/conao/ghq/github.com/conao3/agents-share/src/notes/t3-code-session.md --append-system-prompt \"このセッションが動いているホストは ${lib.removePrefix "conao-nixos-" hostName} (${hostName})。\"";

  cgpuProvider = endpointSecret: servedModel: {
    npm = "@ai-sdk/openai-compatible";
    name = "cgpu modal";
    options = {
      baseURL = config.sops.placeholder.${endpointSecret};
      apiKey = "{file:/home/conao/.config/cgpu/modal/api-key}";
      timeout = 600000;
    };
    models.${servedModel} = {
      name = "${servedModel} (Modal)";
      tool_call = true;
      reasoning = true;
      limit = {
        context = 131072;
        output = 32768;
      };
    };
  };

  cgpuProviderInstance = {
    driver = "opencode";
    displayName = "cgpu modal";
    environment = [
      {
        name = "OPENCODE_CONFIG";
        value = "/home/conao/.config/cgpu/modal/opencode.json";
        sensitive = false;
      }
      {
        name = "OPENCODE_ENABLE_EXA";
        value = "1";
      }
    ];
    enabled = true;
    config = {
      binaryPath = "${inputs.llm-agents.packages.${system}.opencode}/bin/opencode";
    };
  };

  opencodeAgent001ProviderInstance = {
    driver = "opencode";
    displayName = "OpenCode agent001";
    environment = [
      {
        name = "OPENCODE_DB";
        value = "/home/conao/.agents/.opencode.agent001/opencode.db";
        sensitive = false;
      }
    ];
    enabled = true;
    config = {
      binaryPath = "/etc/profiles/per-user/conao/bin/opencode.agent001";
    };
  };

  # Initial content of ~/.t3/userdata/settings.json, used only when the
  # file does not exist yet. After that the file is T3 Code's own: the
  # merge below applies only the OpenCode provider instances and keeps every
  # other key as the file holds it.
  t3SettingsSeed = {
    favorites = [
      {
        provider = "opencode_cgpu_modal";
        model = "qwen3-8-27b/qwen3.8-27b";
      }
      {
        provider = "opencode_cgpu_modal";
        model = "qwen3-6-35b-a3b/qwen3.6-35b-a3b";
      }
      {
        provider = "opencode_cgpu_modal";
        model = "qwen3-6-35b-a3b-abliterated/qwen3.6-35b-a3b-abliterated";
      }
    ];
    providerModelPreferences = {
      opencode_textllm = {
        hiddenModels = [ ];
        modelOrder = [
          "text-llm/qwen3.6-35b-a3b"
          "opencode/beam-free"
          "opencode/big-pickle"
          "opencode/crouton-alpha-free"
          "opencode/deepseek-v4.1-flash-free"
          "opencode/flint-40b-free"
          "opencode/glm-5.3-flash-free"
          "opencode/mimo-v2.6-flash-free"
          "opencode/nemotron-3.5-lightning-free"
          "opencode/nemotron-3.5-super-vl-free"
          "opencode/pulse-alpha-free"
        ];
      };
    };
    defaultModelSelection = {
      instanceId = "claude_conao3";
      model = "claude-opus-5-5";
    };
    projectSettingsFolded = true;
    compactIdleThreads = true;
    idleCompaction = "beforeCacheExpires";
    snoozeLimitedThreads = true;
    autoResumeLimitedThreads = true;
    providerInstances = {
      claude_conao3 = {
        driver = "claudeAgent";
        displayName = "Claude conao3";
        config = {
          homePath = "/home/conao/.agents/.claude.conao3";
          launchArgs = claudeLaunchArgs;
        };
      };
      claude_agent001 = {
        driver = "claudeAgent";
        displayName = "Claude agent001";
        config = {
          homePath = "/home/conao/.agents/.claude.agent001";
          launchArgs = claudeLaunchArgs;
        };
      };
      codex_agent001 = {
        driver = "codex";
        displayName = "Codex agent001";
        config = {
          homePath = "/home/conao/.agents/.codex.agent001";
        };
      };
      codex_agent002 = {
        driver = "codex";
        displayName = "Codex agent002";
        config = {
          homePath = "/home/conao/.agents/.codex.agent002";
        };
      };
      opencode_cgpu_modal = cgpuProviderInstance;
      opencode_agent001 = opencodeAgent001ProviderInstance;
    };
  };

  t3SettingsSeedFile = pkgs.writeText "t3-settings-seed.json" (builtins.toJSON t3SettingsSeed);

  # A programs.agents force op (nix-agents merge.jq format): replaces
  # the OpenCode provider instance subtrees and the Claude launch
  # arguments, keeps every other key.
  t3SettingsOps = pkgs.writeText "t3-settings-ops.json" (
    builtins.toJSON (
      [
        {
          op = "force";
          path = [
            "providerInstances"
            "opencode_agent001"
          ];
          value = opencodeAgent001ProviderInstance;
        }
      ]
      ++
        map
          (instance: {
            op = "force";
            path = [
              "providerInstances"
              instance
              "config"
              "launchArgs"
            ];
            value = claudeLaunchArgs;
          })
          [
            "claude_conao3"
            "claude_agent001"
          ]
      ++ [
        {
          op = "force";
          path = [ "threadTitleInstructions" ];
          value = threadTitleInstructions;
        }
        {
          op = "force";
          path = [ "textGenerationModelSelection" ];
          value = {
            instanceId = "claude_conao3";
            model = "claude-haiku-5-5";
          };
        }
      ]
      ++ lib.optional isEos {
        op = "force";
        path = [
          "providerInstances"
          "opencode_cgpu_modal"
        ];
        value = cgpuProviderInstance;
      }
    )
  );

  # Same merge as programs.agents (nix-agents merge.jq): applies the ops
  # to the current file and writes the result back as a regular file.
  t3SettingsMerge = pkgs.writeShellScript "t3-settings-merge" ''
    set -euo pipefail
    target=$1
    ops=$2
    seed=$3
    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
    if [ -f "$target" ] && [ -s "$target" ]; then
      current=$(${pkgs.coreutils}/bin/cat "$target")
    else
      current=$(${pkgs.coreutils}/bin/cat "$seed")
    fi
    out=$(printf '%s' "$current" \
      | ${lib.getExe pkgs.jq} --slurpfile ops "$ops" --arg label "t3code settings" --arg target "$target" -f ${inputs.nix-agents}/merge.jq)
    tmp=$(${pkgs.coreutils}/bin/mktemp "$(${pkgs.coreutils}/bin/dirname "$target")/.agents-merge.XXXXXX")
    warnings=$(printf '%s' "$out" | ${lib.getExe pkgs.jq} -r '.warnings[]')
    if [ -n "$warnings" ]; then
      printf '%s\n' "$warnings" >> "$(${pkgs.coreutils}/bin/dirname "$target")/settings-warnings.log"
    fi
    printf '%s' "$out" | ${lib.getExe pkgs.jq} '.result' > "$tmp"
    ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
    ${pkgs.coreutils}/bin/mv -T "$tmp" "$target"
  '';
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  home.packages = [
    t3codePackages.t3code
    t3codePackages.t3code-desktop
  ];

  systemd.user.services.t3-thread-retitle = {
    Unit.Description = "Regenerate T3 Code thread titles with their topic tag";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe t3ThreadRetitle;
    };
  };

  systemd.user.timers.t3-thread-retitle = {
    Unit.Description = "Regenerate T3 Code thread titles every 30 minutes";
    Timer = {
      OnCalendar = "*:0/30";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  sops = lib.mkIf isEos {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/conao/.config/sops/age/keys.txt";

    secrets = {
      "cgpu-modal-api-key" = { };
      "exa-api-key" = { };
      "cgpu-modal-endpoint-qwen3-6-35b-a3b" = { };
      "cgpu-modal-endpoint-qwen3-8-27b" = { };
      "cgpu-modal-endpoint-qwen3-6-35b-a3b-abliterated" = { };
    };

    templates."cgpu-opencode-json" = {
      mode = "0600";
      path = "/home/conao/.config/cgpu/modal/opencode.json";
      content = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        provider = {
          "qwen3-6-35b-a3b-abliterated" =
            cgpuProvider "cgpu-modal-endpoint-qwen3-6-35b-a3b-abliterated" "qwen3.6-35b-a3b-abliterated";
          "qwen3-6-35b-a3b" = cgpuProvider "cgpu-modal-endpoint-qwen3-6-35b-a3b" "qwen3.6-35b-a3b";
          "qwen3-8-27b" = cgpuProvider "cgpu-modal-endpoint-qwen3-8-27b" "qwen3.8-27b";
        };
      };
    };
  };

  home.activation = {
    # The decrypted secret paths are runtime paths, so they cannot be
    # home.file sources. Link them into place after activation instead.
    linkAgentSecrets = lib.mkIf isEos (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ln -sf ${
          config.sops.secrets."cgpu-modal-api-key".path
        } /home/conao/.config/cgpu/modal/api-key
        $DRY_RUN_CMD ln -sf ${config.sops.secrets."exa-api-key".path} /home/conao/.config/exa/key
      ''
    );

    mergeT3Settings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${t3SettingsMerge} "$HOME/.t3/userdata/settings.json" ${t3SettingsOps} ${t3SettingsSeedFile}
    '';
  };
}
