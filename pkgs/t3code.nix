{
  inputs,
  pkgs,
  system,
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
  llmAgentsPkgs = inputs.llm-agents.inputs.nixpkgs.legacyPackages.${system};
  t3code = llmAgents.t3code.override {
    codex = pkgs.callPackage ./codex.nix { fallbackPackage = llmAgents.codex; };
    t3code-unwrapped =
      (llmAgentsPkgs.callPackage ./t3code-unwrapped.nix {
        flake = inputs.llm-agents;
        inherit (llmAgents) formatelf versionCheckHomeHook;
      }).overrideAttrs
        (old: {
          patches = (old.patches or [ ]) ++ [
            ./t3code-opencode-console-go-usage.patch
            ./t3code-full-access-no-approval.patch
            ./t3code-new-thread-primary-environment.patch
            ./t3code-done-thread-traversal.patch
            ./t3code-sidebar-host-filter.patch
            ./t3code-sidebar-row-host-chip.patch
            ./t3code-title-regenerate-every-10-messages.patch
            ./t3code-user-message-jump.patch
            ./t3code-environment-label-aliases.patch
            ./t3code-no-inline-visuals.patch
            ./t3code-no-history-swipe.patch
            ./t3code-file-markdown-table-sort.patch
            ./t3code-file-find.patch
            ./t3code-sidebar-launched-threads.patch
            ./t3code-thread-cli-environment.patch
            ./t3code-thread-cli-send-mode.patch
            ./t3code-thread-cli-configure.patch
          ];
        });
  };
in
{
  inherit t3code;
  t3code-desktop = llmAgents.t3code-desktop.override { inherit t3code; };
}
