{ pkgs, lib }:
{
  sharedDir,
  profileDirs,
  exclude,
  forceLinks,
  discard,
  history,
  keepFirst,
}:
let
  coreutils = "${pkgs.coreutils}/bin";
  casePattern = names: if names == [ ] then ''""'' else lib.concatStringsSep " | " names;
  excludeCase = casePattern exclude;
  keepFirstCase = casePattern keepFirst;
  discardCond =
    if discard == [ ] then
      "false"
    else
      lib.concatMapStringsSep " || " (n: ''[ "$e" = "${n}" ]'') discard;
in
''
  shared="${sharedDir}"
  mkdir -p "$shared"
  backupRoot="${sharedDir}.backup-$(${coreutils}/date +%Y%m%d-%H%M%S)"
  profiles=(${lib.concatMapStringsSep " " (d: ''"${d}"'') profileDirs})
  shopt -s dotglob nullglob
  for p in "''${profiles[@]}"; do
    [ -d "$p" ] || continue
    for path in "$p"/*; do
      e="$(${coreutils}/basename "$path")"
      case "$e" in
        ${excludeCase})
          if [ -L "$path" ]; then
            link="$(${coreutils}/readlink "$path")"
            if [ "''${link#"$shared"/}" != "$link" ]; then
              if [ -f "$path" ]; then
                ${coreutils}/cp --remove-destination "$link" "$path"
              else
                ${coreutils}/rm -f "$path"
              fi
            fi
          fi
          continue
          ;;
      esac
      target="$shared/$e"
      if [ -L "$path" ]; then
        ${coreutils}/ln -sfn "$target" "$path"
        continue
      fi
      if [ -d "$path" ]; then
        if [ ! -e "$target" ]; then
          ${coreutils}/mv "$path" "$target"
        else
          ${coreutils}/cp -anl "$path/." "$target/" 2>/dev/null \
            || ${coreutils}/cp -an "$path/." "$target/" 2>/dev/null || true
          ${coreutils}/rm -rf "$path"
        fi
      else
        bdir="$backupRoot/$(${coreutils}/basename "$p")"
        mkdir -p "$bdir"
        ${coreutils}/cp -a "$path" "$bdir/" 2>/dev/null || true
        if [ "$e" = "${history.file}" ]; then
          tmp="$target.merge.$$"
          if [ -e "$target" ]; then
            ${coreutils}/cat "$target" "$path"
          else
            ${coreutils}/cat "$path"
          fi \
            | ${pkgs.jq}/bin/jq -sc 'map(select(type=="object")) | unique | sort_by(${history.sortKey} // 0) | .[]' \
            > "$tmp" 2>/dev/null || ${coreutils}/cp "$path" "$tmp"
          ${coreutils}/mv "$tmp" "$target"
          ${coreutils}/rm -f "$path"
        else
          case "$e" in
            ${keepFirstCase})
              if [ ! -e "$target" ]; then
                ${coreutils}/mv "$path" "$target"
              else
                ${coreutils}/rm -f "$path"
              fi
              ;;
            *)
              if ${discardCond}; then
                ${coreutils}/rm -f "$path"
              elif [ ! -e "$target" ]; then
                ${coreutils}/mv "$path" "$target"
              elif [ "$path" -nt "$target" ]; then
                ${coreutils}/cp -a "$path" "$target"
                ${coreutils}/rm -f "$path"
              else
                ${coreutils}/rm -f "$path"
              fi
              ;;
          esac
        fi
      fi
      ${coreutils}/ln -sfn "$target" "$path"
    done
    for req in ${lib.concatStringsSep " " forceLinks}; do
      ${coreutils}/ln -sfn "$shared/$req" "$p/$req"
    done
    for spath in "$shared"/*; do
      se="$(${coreutils}/basename "$spath")"
      case "$se" in
        ${excludeCase}) continue ;;
      esac
      if [ ! -e "$p/$se" ] && [ ! -L "$p/$se" ]; then
        ${coreutils}/ln -sfn "$spath" "$p/$se"
      fi
    done
  done
''
