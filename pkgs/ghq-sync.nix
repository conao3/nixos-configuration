{
  writeShellScriptBin,
  coreutils,
  gawk,
  gh,
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
    total="$(${gh}/bin/gh api graphql \
      -f query='query($login: String!) { repositoryOwner(login: $login) { repositories(ownerAffiliations: OWNER) { totalCount } } }' \
      -F login="$owner" --jq '.data.repositoryOwner.repositories.totalCount' 2>/dev/null || echo 0)"
    [ "$total" -gt 0 ] || total=1000

    ${gh}/bin/gh repo list "$owner" --limit "$total" --source --json sshUrl --jq '.[].sshUrl' \
      | ${ghq}/bin/ghq get -p 2>&1 | ${gnugrep}/bin/grep -v "exists" || true

    owner_patterns+=(-e "/$owner/")
  done

  bar_opt=""
  [ -t 2 ] && bar_opt="--bar"

  rc=0
  ${ghq}/bin/ghq list -p | ${gnugrep}/bin/grep -F "''${owner_patterns[@]}" \
    | while IFS= read -r r; do
        ${git}/bin/git -C "$r" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true
      done \
    | ${gnused}/bin/sed 's|/\.git$||' \
    | ${gnugrep}/bin/grep -v '^$' \
    | ${coreutils}/bin/sort -u \
    | ${parallel}/bin/parallel $bar_opt --tag --joblog "$log" "$0" --repo {} || rc=$?

  echo
  ${gawk}/bin/gawk 'NR>1 && $7!=0 {print "FAILED: " $NF}' "$log"
  echo "joblog: $log"
  exit "$rc"
''
