{
  writeShellScriptBin,
  coreutils,
  devo,
  gawk,
  git,
  gnugrep,
  gnused,
  nix,
  tmux,
}:

let
  dev = writeShellScriptBin "dev" ''
    set -euo pipefail

    app="dev"
    if [ "''${1:-}" = "stop" ] || [ "''${1:-}" = "dev-stop" ]; then
      app="dev-stop"
      shift
    fi

    remote="$(${git}/bin/git remote get-url origin 2>/dev/null || true)"
    if [ -z "$remote" ]; then
      echo "dev: git remote 'origin' was not found from $(pwd)" >&2
      exit 1
    fi

    repo_path="$(printf '%s\n' "$remote" | ${gnused}/bin/sed -E \
      -e 's#^git@[^:]+:##' \
      -e 's#^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]+/##' \
      -e 's#\.git$##')"
    owner="$(printf '%s\n' "$repo_path" | ${gawk}/bin/awk -F/ '{ print tolower($(NF-1)) }')"
    repo="$(printf '%s\n' "$repo_path" | ${gawk}/bin/awk -F/ '{ print tolower($NF) }')"

    if [ -z "$owner" ] || [ -z "$repo" ] || [ "$owner" = "." ]; then
      echo "dev: failed to infer registry name from origin: $remote" >&2
      exit 1
    fi

    top="$(${git}/bin/git rev-parse --show-toplevel)"
    root_env_name="$(printf '%s_ROOT\n' "$repo" | ${gnused}/bin/sed -E 's/[^a-zA-Z0-9]+/_/g' | ${coreutils}/bin/tr '[:lower:]' '[:upper:]')"
    if [ -z "$(${coreutils}/bin/printenv "$root_env_name" 2>/dev/null || true)" ]; then
      export "$root_env_name=$top"
    fi

    if [ -z "''${SESSION_NAME:-}" ]; then
      canonical="$HOME/ghq/github.com/$owner/$repo"
      if [ "$top" = "$canonical" ]; then
        SESSION_NAME="$repo"
      else
        top_hash="$(printf '%s\n' "$top" | ${coreutils}/bin/cksum | ${gawk}/bin/awk '{ print $1 }')"
        SESSION_NAME="$repo-$top_hash"
      fi
      export SESSION_NAME
    fi

    registry_name="$owner-$repo"
    has_nix_app=0
    if ${nix}/bin/nix registry list 2>/dev/null | ${gnugrep}/bin/grep -qE "^(global|user)[[:space:]]+$registry_name[[:space:]]"; then
      has_nix_app=1
    fi

    if [ "$app" = "dev-stop" ]; then
      if [ "$has_nix_app" = "1" ]; then
        ${nix}/bin/nix run "$registry_name#$app" "$@" || true
      fi
      ${tmux}/bin/tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
    else
      if ${tmux}/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "dev: tmux session '$SESSION_NAME' already exists. Run 'dev stop' first." >&2
        exit 1
      fi
      if [ "$has_nix_app" = "1" ]; then
        exec ${nix}/bin/nix run "$registry_name#$app" "$@"
      else
        exec ${devo}/bin/devo run --attach
      fi
    fi
  '';

  dev-stop = writeShellScriptBin "dev-stop" ''
    exec ${dev}/bin/dev dev-stop "$@"
  '';
in
{
  inherit dev dev-stop;
}
