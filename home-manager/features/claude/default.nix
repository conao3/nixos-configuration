{
  pkgs,
  lib,
  inputs,
  system,
  ...
}:
let
  inherit
    (import ./common.nix {
      inherit
        pkgs
        lib
        inputs
        system
        ;
    })
    llmAgents
    aliasSpecs
    wrapperPackages
    cursorProfilePackages
    sakanaProfilePackages
    ;
in
{
  imports = [
    ./files.nix
    ./dirs.nix
    ./settings.nix
    ./share.nix
    ./codex.nix
    ./cursor.nix
  ];

  home.packages =
    wrapperPackages
    ++ cursorProfilePackages
    ++ sakanaProfilePackages
    ++ [
      inputs.nix-claude-code.packages.${system}.default
      llmAgents.codex
    ]
    ++ map (spec: pkgs.writeShellScriptBin spec.executableName ''exec ${spec.target} "$@"'') aliasSpecs;

  programs.git.ignores = [
    ".claude"
    ".claude-dev"
  ];
}
