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
    claudeSharedDir
    claudeSpecDirs
    codexSharedDir
    codexSpecDirs
    ;

  mkShareReconcile =
    {
      sharedDir,
      specDirs,
      backupPrefix,
      excludeNames,
      historyKey,
      forceLinks,
      discardNames,
    }:
    let
      excludeCase = lib.concatStringsSep " | " excludeNames;
      discardCond =
        if discardNames == [ ] then
          "false"
        else
          lib.concatMapStringsSep " || " (n: ''[ "$e" = "${n}" ]'') discardNames;
    in
    ''
      shared="${sharedDir}"
      mkdir -p "$shared"
      backupRoot="$HOME/.agents/${backupPrefix}.backup-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
      profiles=(${lib.concatStringsSep " " (map (d: "\"" + d + "\"") specDirs)})
      shopt -s dotglob nullglob
      for p in "''${profiles[@]}"; do
        [ -d "$p" ] || continue
        for path in "$p"/*; do
          e="$(${pkgs.coreutils}/bin/basename "$path")"
          case "$e" in
            ${excludeCase}) continue ;;
          esac
          target="$shared/$e"
          if [ -L "$path" ]; then
            ${pkgs.coreutils}/bin/ln -sfn "$target" "$path"
            continue
          fi
          if [ -d "$path" ]; then
            if [ ! -e "$target" ]; then
              ${pkgs.coreutils}/bin/mv "$path" "$target"
            else
              ${pkgs.coreutils}/bin/cp -anl "$path/." "$target/" 2>/dev/null \
                || ${pkgs.coreutils}/bin/cp -an "$path/." "$target/" 2>/dev/null || true
              ${pkgs.coreutils}/bin/rm -rf "$path"
            fi
          else
            bdir="$backupRoot/$(${pkgs.coreutils}/bin/basename "$p")"
            mkdir -p "$bdir"
            ${pkgs.coreutils}/bin/cp -a "$path" "$bdir/" 2>/dev/null || true
            if [ "$e" = "history.jsonl" ]; then
              tmp="$target.merge.$$"
              if [ -e "$target" ]; then
                ${pkgs.coreutils}/bin/cat "$target" "$path"
              else
                ${pkgs.coreutils}/bin/cat "$path"
              fi \
                | ${pkgs.jq}/bin/jq -sc 'map(select(type=="object")) | unique | sort_by(${historyKey} // 0) | .[]' \
                > "$tmp" 2>/dev/null || ${pkgs.coreutils}/bin/cp "$path" "$tmp"
              ${pkgs.coreutils}/bin/mv "$tmp" "$target"
              ${pkgs.coreutils}/bin/rm -f "$path"
            else
              case "$e" in
                *.sqlite | *.sqlite-shm | *.sqlite-wal)
                  if [ ! -e "$target" ]; then
                    ${pkgs.coreutils}/bin/mv "$path" "$target"
                  else
                    ${pkgs.coreutils}/bin/rm -f "$path"
                  fi
                  ;;
                *)
                  if ${discardCond}; then
                    ${pkgs.coreutils}/bin/rm -f "$path"
                  elif [ ! -e "$target" ]; then
                    ${pkgs.coreutils}/bin/mv "$path" "$target"
                  elif [ "$path" -nt "$target" ]; then
                    ${pkgs.coreutils}/bin/cp -a "$path" "$target"
                    ${pkgs.coreutils}/bin/rm -f "$path"
                else
                  ${pkgs.coreutils}/bin/rm -f "$path"
                fi
                ;;
            esac
            fi
          fi
          ${pkgs.coreutils}/bin/ln -sfn "$target" "$path"
        done
        for req in ${lib.concatStringsSep " " forceLinks}; do
          ${pkgs.coreutils}/bin/ln -sfn "$shared/$req" "$p/$req"
        done
        for spath in "$shared"/*; do
          se="$(${pkgs.coreutils}/bin/basename "$spath")"
          case "$se" in
            ${excludeCase}) continue ;;
          esac
          if [ ! -e "$p/$se" ] && [ ! -L "$p/$se" ]; then
            ${pkgs.coreutils}/bin/ln -sfn "$spath" "$p/$se"
          fi
        done
      done
    '';
in
{
  home.activation.claudeShareReconcile =
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "ensureAgentDirs"
        "agentInstructions"
        "claudeSettings"
      ]
      (mkShareReconcile {
        sharedDir = claudeSharedDir;
        specDirs = claudeSpecDirs;
        backupPrefix = ".claude";
        excludeNames = [
          ".claude.json"
          ".credentials.json"
        ];
        historyKey = ".timestamp";
        forceLinks = [
          "settings.json"
          "CLAUDE.md"
        ];
        discardNames = [
          "settings.json"
          "CLAUDE.md"
        ];
      });

  home.activation.codexShareReconcile =
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "ensureAgentDirs"
        "agentInstructions"
      ]
      (mkShareReconcile {
        sharedDir = codexSharedDir;
        specDirs = codexSpecDirs;
        backupPrefix = ".codex";
        excludeNames = [ "auth.json" ];
        historyKey = ".ts";
        forceLinks = [
          "config.toml"
          "AGENTS.md"
        ];
        discardNames = [ "AGENTS.md" ];
      });
}
