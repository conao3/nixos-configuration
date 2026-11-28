{ pkgs }:
pkgs.writeShellScript "agent-ci-wait-hook" ''
  set -euo pipefail
  format="''${1:-claude}"
  if [ "$format" = cursor ]; then
    field='.command // empty'
  else
    field='.tool_input.command // empty'
  fi
  command="$(${pkgs.jq}/bin/jq -r "$field")"
  if ! printf '%s\n' "$command" | ${pkgs.gnugrep}/bin/grep -Eq '(^|[;&|(`]|\$\(|(^|[[:space:]])(do|then|else|time|timeout[[:space:]]+[0-9]+[a-z]?))[[:space:]]*gh[[:space:]]+(run[[:space:]]+watch|pr[[:space:]]+checks[^;&|]*--watch)([[:space:]]|$)'; then
    [ "$format" = cursor ] && echo '{}'
    exit 0
  fi
  message='CI の完了は `gh lookout wait <owner>/<repo> <sha>` で待つ (MEMORY.md「git 運用」)。この `gh run watch` / `gh pr checks --watch` の呼び出しは止めた。'
  case "$format" in
    cursor) ${pkgs.jq}/bin/jq -nc --arg m "$message" '{permission: "deny", user_message: $m, agent_message: $m}' ;;
    devin) ${pkgs.jq}/bin/jq -nc --arg m "$message" '{decision: "block", reason: $m}' ;;
    *)
      echo "$message" >&2
      exit 2
      ;;
  esac
''
