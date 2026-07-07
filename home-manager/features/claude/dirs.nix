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
  agmsg = pkgs.callPackage ../../../pkgs/agmsg.nix { src = inputs.agmsg; };
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

  home.activation.agmsgSkill = lib.hm.dag.entryAfter [ "writeBoundary" "ensureAgentDirs" ] ''
    skill_dir="$HOME/.agents/skills/agmsg"
    mkdir -p "$skill_dir"/{db,teams,run,agents}

    rm -rf "$skill_dir/scripts"
    cp -rL "${agmsg}/share/agmsg/scripts" "$skill_dir/scripts"
    chmod -R u+w "$skill_dir/scripts"

    rm -rf "$skill_dir/plugins"
    cp -rL "${agmsg}/share/agmsg/plugins" "$skill_dir/plugins"
    chmod -R u+w "$skill_dir/plugins"

    ${pkgs.coreutils}/bin/install -m 644 "${agmsg}/share/agmsg/SKILL.md" "$skill_dir/SKILL.md"
    ${pkgs.coreutils}/bin/install -m 644 "${agmsg}/share/agmsg/openai.yaml" "$skill_dir/agents/openai.yaml"
    ${pkgs.coreutils}/bin/install -m 644 "${agmsg}/share/agmsg/VERSION" "$skill_dir/VERSION"
    ${pkgs.coreutils}/bin/install -m 755 "${agmsg}/share/agmsg/uninstall.sh" "$skill_dir/uninstall.sh"

    touch "$skill_dir/.agmsg"

    if [ ! -f "$skill_dir/db/messages.db" ]; then
      PATH="${lib.makeBinPath [ pkgs.sqlite ]}:$PATH" ${pkgs.bash}/bin/bash "$skill_dir/scripts/internal/init-db.sh"
    fi

    if [ ! -f "$skill_dir/db/config.yaml" ]; then
      PATH="${lib.makeBinPath [ pkgs.sqlite ]}:$PATH" ${pkgs.bash}/bin/bash "$skill_dir/scripts/config.sh" show >/dev/null
    fi

    shared_commands="$HOME/.agents/.claude/commands"
    mkdir -p "$shared_commands"
    ${pkgs.gnused}/bin/sed "s/__SKILL_NAME__/agmsg/g" "${agmsg}/share/agmsg/scripts/drivers/types/claude-code/template.md" > "$shared_commands/agmsg.md"
  '';
}
