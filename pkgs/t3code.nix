{
  inputs,
  pkgs,
  system,
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
  t3code = llmAgents.t3code.override {
    codex = pkgs.callPackage ./codex.nix { fallbackPackage = llmAgents.codex; };
    t3code-unwrapped = llmAgents.t3code.unwrapped.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./t3code-sol-medium-effort.patch
        ./t3code-html-preview-file-revision.patch
        ./t3code-opencode-console-go-usage.patch
        ./t3code-full-access-no-approval.patch
        ./t3code-new-thread-primary-environment.patch
        ./t3code-delete-finished-once-tasks.patch
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
      ];
    });
  };
in
{
  inherit t3code;
  t3code-desktop = llmAgents.t3code-desktop.override { inherit t3code; };
}
