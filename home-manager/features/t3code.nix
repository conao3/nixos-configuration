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
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  home.packages = [
    t3codePackages.t3code
    t3codePackages.t3code-desktop
  ];

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

  home.file = lib.mkIf isEos {
    ".t3/userdata/settings.json".text = builtins.toJSON {
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
            launchArgs = "--append-system-prompt-file /home/conao/ghq/github.com/conao3/agents-share/src/notes/t3-code-session.md";
          };
        };
        claude_agent001 = {
          driver = "claudeAgent";
          displayName = "Claude agent001";
          config = {
            homePath = "/home/conao/.agents/.claude.agent001";
            launchArgs = "--append-system-prompt-file /home/conao/ghq/github.com/conao3/agents-share/src/notes/t3-code-session.md";
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
        opencode_cgpu_modal = {
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
            binaryPath = "opencode";
          };
        };
      };
    };
  };

  # The decrypted secret paths are runtime paths, so they cannot be
  # home.file sources. Link them into place after activation instead.
  home.activation = lib.mkIf isEos {
    linkAgentSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ln -sf ${config.sops.secrets."cgpu-modal-api-key".path} /home/conao/.config/cgpu/modal/api-key
      $DRY_RUN_CMD ln -sf ${config.sops.secrets."exa-api-key".path} /home/conao/.config/exa/key
    '';
  };
}
