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
  isEos =
    pkgs.stdenv.hostPlatform.isLinux
    && osConfig != null
    && osConfig.networking.hostName == "conao-nixos-eos";

  home = config.home.homeDirectory;
  profileBin = "${config.home.profileDirectory}/bin";
  bbCli = "${inputs.llm-agents.packages.${system}.bb-app}/bin/bb";
  envBin = "${pkgs.coreutils}/bin/env";

  # Global machine variables: bb's built-in claude-code and codex providers
  # run on the same agent homes as T3 Code's claude_conao3 / codex_agent001.
  machineEnv = {
    CLAUDE_CONFIG_DIR = "${home}/.agents/.claude.conao3";
    CODEX_HOME = "${home}/.agents/.codex.agent001";
  };

  # ACP providers for the other T3 Code provider instances. The machine
  # variables above take precedence over a custom agent's `env`, so the
  # agent homes are set through `env` in the command instead.
  customAgents = [
    {
      id = "claude-agent001";
      displayName = "Claude agent001";
      command = envBin;
      args = [
        "CLAUDE_CONFIG_DIR=${home}/.agents/.claude.agent001"
        "${profileBin}/claude-agent-acp"
      ];
    }
    {
      id = "codex-agent002";
      displayName = "Codex agent002";
      command = envBin;
      args = [
        "CODEX_HOME=${home}/.agents/.codex.agent002"
        "${profileBin}/codex-acp"
      ];
    }
    {
      id = "devin";
      displayName = "Devin";
      command = "${profileBin}/devin";
      args = [ "acp" ];
    }
  ]
  ++ lib.optional isEos {
    id = "cgpu-modal";
    displayName = "cgpu modal";
    command = "${inputs.llm-agents.packages.${system}.opencode}/bin/opencode";
    args = [ "acp" ];
    dialect = "opencode";
    env = {
      OPENCODE_CONFIG = "${home}/.config/cgpu/modal/opencode.json";
      OPENCODE_ENABLE_EXA = "1";
    };
  };

  customAgentsFile = pkgs.writeText "bb-custom-agents.json" (builtins.toJSON customAgents);

  # The settings live in bb's database, so they are applied through the
  # running server. A switch while bb is not running skips them; the next
  # switch with bb running applies them.
  bbConfigure = pkgs.writeShellScript "bb-configure" ''
    set -euo pipefail
    if ! ${pkgs.curl}/bin/curl -fsS --max-time 2 -o /dev/null http://127.0.0.1:38886/health; then
      echo "bb: server not running; skipped applying bb settings" >&2
      exit 0
    fi
    ${lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        printf '%s' ${lib.escapeShellArg value} | ${bbCli} machine env set ${name} >/dev/null
      '') machineEnv
    )}
    ${bbCli} plugin config provider-acp set customAgents "$(${lib.getExe pkgs.jq} -c . ${customAgentsFile})" >/dev/null
    ${bbCli} settings general defaultProviderId claude-code >/dev/null
  '';
in
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = [
    (pkgs.callPackage ../../pkgs/bb-desktop.nix { })
  ];

  home.file.".bb/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${home}/ghq/github.com/conao3/agents-share/src/notes/bb-session.md";

  home.activation.configureBb = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${bbConfigure}
  '';
}
