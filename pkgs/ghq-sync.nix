{
  writeShellScriptBin,
  coreutils,
  git,
  gnugrep,
  gnused,
  parallel,
  ghq,
  openssh,
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
    -j N, --jobs=N        concurrent repositories (default: 8)
    --connect-timeout=N   SSH connection timeout in seconds (default: 10)
    --fetch-retries=N     extra fetch attempts (default: 1)
    --no-ssh-reuse        disable per-run SSH connection sharing
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
    for name in help owner repo jobs connect-timeout fetch-retries no-ssh-reuse; do
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
  jobs=8
  connect_timeout=10
  fetch_retries=1
  ssh_reuse=1
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
        if [ "$option" = "no-ssh-reuse" ]; then
          [ "$has_value" -eq 0 ] || die "--no-ssh-reuse option does not take a value"
          ssh_reuse=0
          continue
        fi
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
          jobs) jobs="$value" ;;
          connect-timeout) connect_timeout="$value" ;;
          fetch-retries) fetch_retries="$value" ;;
        esac
        ;;
      -j)
        [ $# -gt 0 ] || die "-j option requires 1 argument"
        jobs="$1"
        shift
        ;;
      -j*)
        jobs="''${arg#-j}"
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

  [[ "$jobs" =~ ^[1-9][0-9]*$ ]] || die "jobs must be a positive integer"
  [[ "$connect_timeout" =~ ^[1-9][0-9]*$ ]] || die "connect-timeout must be a positive integer"
  [[ "$fetch_retries" =~ ^(0|[1-9][0-9]*)$ ]] || die "fetch-retries must be a non-negative integer"

  cleanup_ssh_control() {
    local socket
    for socket in "$GHQ_SYNC_SSH_CONTROL_DIR"/*; do
      [ -S "$socket" ] || continue
      ${openssh}/bin/ssh -S "$socket" -O exit localhost >/dev/null 2>&1 || true
    done
    ${coreutils}/bin/rm -rf -- "$GHQ_SYNC_SSH_CONTROL_DIR"
  }

  init_ssh_control() {
    [ "$ssh_reuse" -eq 1 ] || return 0
    if [ -z "''${GHQ_SYNC_SSH_CONTROL_DIR:-}" ]; then
      GHQ_SYNC_SSH_CONTROL_DIR="$(${coreutils}/bin/mktemp -d /tmp/ghqs.XXXXXX)" || exit 1
      export GHQ_SYNC_SSH_CONTROL_DIR
      trap cleanup_ssh_control EXIT
    fi
  }

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

    ssh_command="''${GIT_SSH_COMMAND:-$(${git}/bin/git -C "$repo" config --get core.sshCommand || true)}"
    [ -n "$ssh_command" ] || ssh_command="${openssh}/bin/ssh"
    init_ssh_control
    control_options=""
    if [ "$ssh_reuse" -eq 1 ]; then
      ssh_key="$(printf '%s' "$ssh_command" | ${coreutils}/bin/sha256sum)"
      ssh_key="''${ssh_key:0:8}"
      control_options="-o ControlMaster=auto -o ControlPersist=60 -o ControlPath=$GHQ_SYNC_SSH_CONTROL_DIR/$ssh_key-%C"
    fi
    export GIT_SSH_COMMAND="$ssh_command -o ConnectTimeout=$connect_timeout -o ConnectionAttempts=1 $control_options"

    fetch_attempt=0
    until ${git}/bin/git -C "$repo" fetch --quiet; do
      if [ "$fetch_attempt" -ge "$fetch_retries" ]; then
        echo "FETCH-FAIL"
        exit 1
      fi
      fetch_attempt=$((fetch_attempt + 1))
      echo "fetch retry $fetch_attempt/$fetch_retries" >&2
      ${coreutils}/bin/sleep 1
    done

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

  init_ssh_control
  child_options=()
  [ "$ssh_reuse" -eq 1 ] || child_options+=(--no-ssh-reuse)
  rc=0
  ${ghq}/bin/ghq list -p | ${gnugrep}/bin/grep -F "''${owner_patterns[@]}" \
    | while IFS= read -r r; do
        ${git}/bin/git -C "$r" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true
      done \
    | ${gnused}/bin/sed 's|/\.git$||' \
    | ${gnugrep}/bin/grep -v '^$' \
    | ${coreutils}/bin/sort -u \
    | ${parallel}/bin/parallel $bar_opt --jobs "$jobs" --joblog "$log" --results "$results_dir" "$0" "''${child_options[@]}" --jobs "$jobs" --connect-timeout "$connect_timeout" --fetch-retries "$fetch_retries" --repo {} || rc=$?

  declare -A repo_by_seq=()
  declare -A exit_by_seq=()
  declare -A status_by_seq=()
  while IFS=$'\t' read -r seq _host _start _runtime _send _receive exitval _signal command; do
    case "$seq" in
      Seq|''') continue ;;
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
