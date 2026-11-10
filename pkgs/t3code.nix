{
  inputs,
  system,
}:
let
  llmAgents = inputs.llm-agents.packages.${system};
  t3code = llmAgents.t3code.override {
    t3code-unwrapped = llmAgents.t3code.unwrapped.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./t3code-html-preview-file-revision.patch
        ./t3code-opencode-console-go-usage.patch
        ./t3code-full-access-no-approval.patch
        ./t3code-new-thread-primary-environment.patch
        ./t3code-delete-finished-once-tasks.patch
      ];
    });
  };
in
{
  inherit t3code;
  t3code-desktop = llmAgents.t3code-desktop.override { inherit t3code; };
}
