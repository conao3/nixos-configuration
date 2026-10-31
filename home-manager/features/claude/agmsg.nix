{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  agmsg = pkgs.callPackage ../../../pkgs/agmsg.nix { src = inputs.agmsg; };
in
{
  programs.agents.zshFunctions.codex = ''AGMSG_REAL_CODEX=${config.programs.agents.types.codex.executable} "$HOME/.agents/skills/agmsg/scripts/drivers/types/codex/codex-shim.sh"'';

  home.activation.agmsgSkill = lib.hm.dag.entryAfter [ "writeBoundary" "agentsDirs" ] ''
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
      PATH="${
        lib.makeBinPath [ pkgs.sqlite ]
      }:$PATH" ${pkgs.bash}/bin/bash "$skill_dir/scripts/internal/init-db.sh"
    fi

    if [ ! -f "$skill_dir/db/config.yaml" ]; then
      PATH="${
        lib.makeBinPath [ pkgs.sqlite ]
      }:$PATH" ${pkgs.bash}/bin/bash "$skill_dir/scripts/config.sh" show >/dev/null
    fi

    shared_commands="$HOME/.agents/.claude/commands"
    mkdir -p "$shared_commands"
    ${pkgs.gnused}/bin/sed "s/__SKILL_NAME__/agmsg/g" "${agmsg}/share/agmsg/scripts/drivers/types/claude-code/template.md" > "$shared_commands/agmsg.md"
  '';
}
