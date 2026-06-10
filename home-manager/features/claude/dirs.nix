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
    agentDirs
    ;
  soulTemplate = pkgs.writeText "SOUL.md" (builtins.readFile ./SOUL.md);
  identityTemplate = pkgs.writeText "IDENTITY.md" (builtins.readFile ./IDENTITY.md);
in
{
  home.activation.ensureAgentDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatMapStringsSep "\n" (dir: "mkdir -p ${dir}") agentDirs}
  '';

  # MEMORYない方が良いのではという疑惑。エージェントレベルは無効化する。
  # home.activation.agentTemplates = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
  #   if [ ! -f "$HOME/.agents/share/MEMORY.md" ]; then
  #     touch "$HOME/.agents/share/MEMORY.md"
  #   fi
  #   ${lib.concatMapStringsSep "\n" (spec: ''
  #     if [ ! -f "$HOME/${spec.dir}/SOUL.md" ]; then
  #       ${pkgs.coreutils}/bin/install -m 644 ${soulTemplate} "$HOME/${spec.dir}/SOUL.md"
  #     fi
  #     if [ ! -f "$HOME/${spec.dir}/IDENTITY.md" ]; then
  #       ${pkgs.coreutils}/bin/install -m 644 ${identityTemplate} "$HOME/${spec.dir}/IDENTITY.md"
  #     fi
  #     if [ ! -f "$HOME/${spec.dir}/MEMORY.md" ]; then
  #       touch "$HOME/${spec.dir}/MEMORY.md"
  #     fi
  #     mkdir -p "$HOME/${spec.dir}/MEMORY"
  #   '') wrapperSpecs}
  # '';

  home.activation.agentTemplates = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
    if [ ! -f "$HOME/.agents/share/MEMORY.md" ]; then
      touch "$HOME/.agents/share/MEMORY.md"
    fi
    mkdir -p "$HOME"/.agents/share/MEMORY_SUGGEST
    mkdir -p "$HOME"/.agents/share/projects
    mkdir -p "$HOME"/.agents/share/notes
  '';
}
