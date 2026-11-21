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
  bbApp = "${inputs.llm-agents.packages.${system}.bb-app}/bin/bb-app";
  tailscale = "/run/current-system/sw/bin/tailscale";
  jq = lib.getExe pkgs.jq;
  bbServerPort = "38886";
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

  # bb-plugins/tweaks carries the features that T3 Code gets from
  # pkgs/t3code-*.patch. Its commands take the keys the T3 Code patches use,
  # and Alt+P is freed from bb's provider cycling for them.
  tweaksPluginSource = "git:https://github.com/conao3/nixos-configuration";
  keyboardShortcuts = {
    "modelPicker.cycleProvider" = "disabled";
    "plugin:tweaks/next-user-message" = "Alt+n";
    "plugin:tweaks/previous-user-message" = "Alt+p";
    "plugin:tweaks/next-attention-thread" = "Alt+o";
  };

  # The same title instructions as T3 Code's threadTitleInstructions. The
  # plugin pipes its prompt to this command at the end of a thread's first
  # turn and then every tenth user message.
  tweaksSettings = {
    titleInstructions = "Write the title in English, and end it with category tags separated by single spaces (e.g. \"Find a home in Toronto #housing #canada\"). Each tag is # followed by one lowercase English word naming the area of the work (e.g. #job #accounting #housing #english #routine #t3code #nixos). Add as many tags as apply. Keep the tags of the previous title when they still fit the current work.";
    titleCommand = "cd /tmp && ${envBin} CLAUDE_CONFIG_DIR=${home}/.agents/.claude.conao3 ${profileBin}/claude -p --model claude-haiku-5-5 --system-prompt 'You write titles for coding-agent conversations.' --setting-sources '' --strict-mcp-config --no-session-persistence";
  };

  customAgentsFile = pkgs.writeText "bb-custom-agents.json" (builtins.toJSON customAgents);

  # The settings live in bb's database, so they are applied through the
  # running server. A switch while bb is not running skips them; the next
  # switch with bb running applies them.
  bbConfigure = pkgs.writeShellScript "bb-configure" ''
    set -uo pipefail
    if ! ${pkgs.curl}/bin/curl -fsS --max-time 2 -o /dev/null http://127.0.0.1:${bbServerPort}/health; then
      echo "bb: server not running; skipped applying bb settings" >&2
      exit 0
    fi
    warn() { echo "warning: bb: could not apply $1" >&2; }
    ${lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        printf '%s' ${lib.escapeShellArg value} | ${bbCli} machine env set ${name} >/dev/null || warn "machine env ${name}"
      '') machineEnv
    )}
    ${bbCli} plugin config provider-acp set customAgents "$(${jq} -c . ${customAgentsFile})" >/dev/null || warn "customAgents"
    ${bbCli} settings general defaultProviderId claude-code >/dev/null || warn "defaultProviderId"
    if ! ${bbCli} plugin list 2>/dev/null | grep -q '^tweaks@'; then
      ${bbCli} plugin install ${tweaksPluginSource} --subdirectory bb-plugins/tweaks --yes >/dev/null || warn "the tweaks plugin"
    fi
    ${lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        ${bbCli} plugin config tweaks set ${name} ${lib.escapeShellArg value} >/dev/null || warn "tweaks ${name}"
      '') tweaksSettings
    )}
    ${bbCli} plugin disable inline-vis >/dev/null || warn "inline-vis"
    ${bbCli} settings experiment threadRowMetadata true >/dev/null || warn "threadRowMetadata"
    ${bbCli} thread-list prefs set showRowMetadata true >/dev/null || warn "showRowMetadata"
    ${lib.concatStrings (
      lib.mapAttrsToList (command: shortcut: ''
        ${bbCli} settings keyboard set ${command} ${shortcut} >/dev/null || warn "the shortcut of ${command}"
      '') keyboardShortcuts
    )}
    ${lib.optionalString isEos ''
      tailnet_name=$(${tailscale} status --json | ${jq} -r '.Self.DNSName | rtrimstr(".")')
      if [ -n "$tailnet_name" ]; then
        server_url="https://$tailnet_name:${bbServerPort}"
        ${tailscale} serve --bg --https ${bbServerPort} http://127.0.0.1:${bbServerPort} >/dev/null || warn "tailscale serve"
        ${bbApp} config set BB_APP_URL "$server_url" >/dev/null || warn "BB_APP_URL"
        ${bbCli} settings general machineServerUrl "$server_url" >/dev/null || warn "machineServerUrl"
        ${bbCli} settings general defaultMachineAccess direct >/dev/null || warn "defaultMachineAccess"
      else
        warn "the tailnet name of this host"
      fi
    ''}
  '';
in
lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  home.packages = [
    (pkgs.callPackage ../../pkgs/bb-desktop.nix { })
  ];

  home.file.".bb/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${home}/ghq/github.com/conao3/agents-share/src/notes/bb-session.md";

  xdg.configFile."systemd/user/bb-host-daemon-.service.d/claude.conf".text = ''
    [Service]
    Environment=BB_CLAUDE_CODE_EXECUTABLE=${profileBin}/claude
  '';

  home.activation.configureBb = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $DRY_RUN_CMD ${bbConfigure}
  '';
}
