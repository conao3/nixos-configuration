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
    t3code-unwrapped = (llmAgentsPkgs.callPackage ./t3code-unwrapped.nix { flake = inputs.llm-agents; inherit (llmAgents) formatelf versionCheckHomeHook; }).overrideAttrs (old: {
      patches = old.patches or [ ];
    });
  };
in
{
  inherit t3code;
  t3code-desktop = llmAgents.t3code-desktop.override { inherit t3code; };
}
