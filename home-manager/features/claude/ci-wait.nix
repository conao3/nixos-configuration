{ pkgs, lib, ... }:
let
  hook = import ./ci-wait/hook.nix { inherit pkgs; };
  devinHooks = {
    PreToolUse = [
      {
        matcher = "exec";
        hooks = [
          {
            type = "command";
            command = "${hook} devin";
            timeout = 10;
          }
        ];
      }
    ];
  };
in
{
  programs.agents.types.codex.files."rules/ci.rules" = {
    strategy = "overwrite";
    source = ./ci-wait/codex.rules;
  };

  programs.agents.types.opencode.files."plugins/ci-wait.ts" = {
    strategy = "link";
    source = ./ci-wait/opencode-plugin.ts;
  };

  home.file.".cursor/hooks.json".text = builtins.toJSON {
    version = 1;
    hooks.beforeShellExecution = [ { command = "${hook} cursor"; } ];
  };

  home.activation.devinCiWaitHook = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config="$HOME/.agents/.devin.conao3/config.json"
    if [ -f "$config" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp "$config.XXXXXX")"
      ${pkgs.jq}/bin/jq --argjson hooks ${lib.escapeShellArg (builtins.toJSON devinHooks)} '.hooks = $hooks' "$config" > "$tmp"
      ${pkgs.coreutils}/bin/chmod 600 "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$config"
    fi
  '';
}
