{
  writeShellScriptBin,
  coreutils,
  git,
  gnugrep,
  gnused,
  parallel,
  ghq,
}:

writeShellScriptBin "ghq-sync" ''
  set -uo pipefail

  usage() {
    cat <<'EOF'
  Usage: ghq-sync [options]

  Options:
    -h, --help            show this help message and exit
    -o OWNER, --owner=OWNER
                          sync the repositories of OWNER; may be given more
                          than once (default: conao3, sancode-org)
    --repo=PATH           sync only the repository at PATH
  EOF
  }

  die() {
    echo "Usage: ghq-sync [options]" >&2
    echo >&2
    echo "ghq-sync: error: $1" >&2
    exit 2
  }

  resolve_long_option() {
    local given="$1" name match="" count=0
    for name in help owner repo; do
      [ "$name" = "$given" ] && { echo "$name"; return 0; }
      case "$name" in
        "$given"*) match="$name"; count=$((count + 1)) ;;
      esac
    done
    [ "$count" -eq 1 ] && [ -n "$given" ] && { echo "$match"; return 0; }
    return 1
  }

  owners=()
  repo=""
  positional=()

  while [ $# -gt 0 ]; do
    arg="$1"
    shift
    case "$arg" in
      --)
        positional+=("$@")
        break
        ;;
      --*)
        name="''${arg#--}"
        value=""
        has_value=0
        case "$name" in
          *=*)
            value="''${name#*=}"
            name="''${name%%=*}"
            has_value=1
            ;;
        esac
        option="$(resolve_long_option "$name")" || die "no such option: --$name"
        if [ "$option" = "help" ]; then
          [ "$has_value" -eq 0 ] || die "--help option does not take a value"
          usage
          exit 0
        fi
        if [ "$has_value" -eq 0 ]; then
          [ $# -gt 0 ] || die "--$option option requires 1 argument"
          value="$1"
          shift
        fi
        case "$option" in
          owner) owners+=("$value") ;;
          repo) repo="$value" ;;
        esac
        ;;
      -h)
        usage
        exit 0
        ;;
      -o)
        [ $# -gt 0 ] || die "-o option requires 1 argument"
        owners+=("$1")
        shift
        ;;
      -o*)
        owners+=("''${arg#-o}")
        ;;
      -?*)
        die "no such option: $arg"
        ;;
      *)
        positional+=("$arg")
        ;;
    esac
  done

  [ "''${#positional[@]}" -eq 0 ] || die "unexpected argument: ''${positional[0]}"
  for owner in "''${owners[@]}"; do
    [ -n "$owner" ] || die "OWNER must not be empty"
  done

  if [ -n "$repo" ]; then
    [ "''${#owners[@]}" -eq 0 ] || die "--repo cannot be used with --owner"

    if [ -d "$(${git}/bin/git -C "$repo" rev-parse --path-format=absolute --git-path rebase-merge)" ] \
      || [ -d "$(${git}/bin/git -C "$repo" rev-parse --path-format=absolute --git-path rebase-apply)" ]; then
      echo "SKIP(rebase-in-progress)"
      exit 1
    fi

    if ! ${git}/bin/git -C "$repo" symbolic-ref -q HEAD >/dev/null; then
      echo "SKIP(detached-head)"
      exit 0
    fi

    if ! ${git}/bin/git -C "$repo" rev-parse -q --verify '@{u}' >/dev/null 2>&1; then
      echo "SKIP(no-upstream)"
      exit 0
    fi

    if ! ${git}/bin/git -C "$repo" fetch --quiet; then
      echo "FETCH-FAIL"
      exit 1
    fi

    behind="$(${git}/bin/git -C "$repo" rev-list --count 'HEAD..@{u}')"
    if [ "$behind" -gt 0 ]; then
      if ! ${git}/bin/git -C "$repo" rebase --autostash --quiet '@{u}' >/dev/null 2>&1; then
        ${git}/bin/git -C "$repo" rebase --abort >/dev/null 2>&1 || true
        echo "REBASE-CONFLICT"
        exit 1
      fi
    fi

    ahead="$(${git}/bin/git -C "$repo" rev-list --count '@{u}..HEAD')"
    if [ "$ahead" -gt 0 ]; then
      if ! ${git}/bin/git -C "$repo" push --quiet; then
        echo "PUSH-FAIL"
        exit 1
      fi
      echo "PUSHED ($ahead commits)"
    fi
    exit 0
  fi

  [ "''${#owners[@]}" -gt 0 ] || owners=(conao3 sancode-org)

  log_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/ghq-sync"
  ${coreutils}/bin/mkdir -p "$log_dir"
  log="$log_dir/$(${coreutils}/bin/date +%Y%m%d-%H%M%S).log"

  owner_patterns=()
  for owner in "''${owners[@]}"; do
    owner_patterns+=(-e "/$owner/")
  done

  bar_opt=""
  [ -t 2 ] && bar_opt="--bar"

  results_dir="''${log%.log}.results"

  rc=0
  ${ghq}/bin/ghq list -p | ${gnugrep}/bin/grep -F "''${owner_patterns[@]}" \
    | while IFS= read -r r; do
        ${git}/bin/git -C "$r" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true
      done \
    | ${gnused}/bin/sed 's|/\.git$||' \
    | ${gnugrep}/bin/grep -v '^$' \
    | ${coreutils}/bin/sort -u \
    | ${parallel}/bin/parallel $bar_opt --joblog "$log" --results "$results_dir" "$0" --repo {} || rc=$?

  declare -A repo_by_seq=()
  declare -A exit_by_seq=()
  declare -A status_by_seq=()
  while IFS=$'\t' read -r seq _host _start _runtime _send _receive exitval _signal command; do
    case "$seq" in
      Seq|'') continue ;;
    esac
    repo_by_seq["$seq"]="''${command##* }"
    exit_by_seq["$seq"]="$exitval"
  done < "$log"

  for out_file in "$results_dir"/*/*/stdout; do
    [ -f "$out_file" ] || continue
    seq="$(cat "''${out_file%/*}/seq")"
    status_by_seq["$seq"]="$(cat "$out_file")"
  done

  pushed=()
  skipped=()
  failed=()
  for seq in "''${!repo_by_seq[@]}"; do
    repo="''${repo_by_seq[$seq]}"
    status="''${status_by_seq[$seq]:-}"
    case "$status" in
      PUSHED*) pushed+=("$repo: $status") ;;
      SKIP*) skipped+=("$repo: $status") ;;
      *) [ "''${exit_by_seq[$seq]}" != "0" ] && failed+=("$repo: ''${status:-no output}") ;;
    esac
  done

  echo
  echo "summary:"
  if [ "''${#pushed[@]}" -gt 0 ]; then
    printf '%s\n' "''${pushed[@]}" | ${coreutils}/bin/sort | ${gnused}/bin/sed 's/^/  pushed: /'
  fi
  if [ "''${#skipped[@]}" -gt 0 ]; then
    printf '%s\n' "''${skipped[@]}" | ${coreutils}/bin/sort | ${gnused}/bin/sed 's/^/  skipped: /'
  fi
  if [ "''${#failed[@]}" -gt 0 ]; then
    printf '%s\n' "''${failed[@]}" | ${coreutils}/bin/sort | ${gnused}/bin/sed 's/^/  failed: /'
  fi
  if [ "''${#pushed[@]}" -eq 0 ] && [ "''${#skipped[@]}" -eq 0 ] && [ "''${#failed[@]}" -eq 0 ]; then
    echo "  all repositories are up to date"
  fi
  echo "joblog: $log"
  exit "$rc"
''
