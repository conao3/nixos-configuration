{
  writeShellScriptBin,
  coreutils,
  gawk,
  gh,
  git,
  gnugrep,
  parallel,
  ghq,
}:

writeShellScriptBin "ghq-sync" ''
  set -uo pipefail

  if [ "''${1:-}" = "--repo" ]; then
    repo="$2"

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

  owner="''${1:-conao3}"
  log_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/ghq-sync"
  ${coreutils}/bin/mkdir -p "$log_dir"
  log="$log_dir/$(${coreutils}/bin/date +%Y%m%d-%H%M%S).log"

  ${gh}/bin/gh repo list "$owner" --limit 1000 --source --json sshUrl --jq '.[].sshUrl' \
    | ${ghq}/bin/ghq get -p 2>&1 | ${gnugrep}/bin/grep -v "exists" || true

  bar_opt=""
  [ -t 2 ] && bar_opt="--bar"

  rc=0
  ${ghq}/bin/ghq list -p | ${gnugrep}/bin/grep "/$owner/" \
    | ${parallel}/bin/parallel $bar_opt --tag --joblog "$log" "$0" --repo {} || rc=$?

  echo
  ${gawk}/bin/gawk 'NR>1 && $7!=0 {print "FAILED: " $NF}' "$log"
  echo "joblog: $log"
  exit "$rc"
''
