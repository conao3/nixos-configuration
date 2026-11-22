state=${XDG_STATE_HOME:-$HOME/.local/state}/agent-board
pending=$state/pending
mkdir -p "$pending"

attempt() {
  local host=$1 input=$2 dest
  shift 2
  if ! dest=$(jq -er --arg host "$host" 'if has($host) then .[$host] // "" else error("unknown host") end' <<<"$AGENT_BOARD_HOSTS"); then
    echo "agent-board-deliver: host $host is not registered in AGENT_BOARD_HOSTS" >&2
    return 2
  fi
  if [ -z "$dest" ]; then
    agent-board-local "$@" <<<"$input"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$dest" "agent-board-local $(printf '%q ' "$@")" <<<"$input"
  fi
}

if [ "${1:-}" = --retry ]; then
  declare -A down=()
  for file in "$pending"/*.json; do
    [ -e "$file" ] || continue
    host=$(jq -r '.host' "$file")
    [ -n "${down[$host]:-}" ] && continue
    mapfile -t args < <(jq -r '.args[]' "$file")
    if attempt "$host" "$(jq -r '.input' "$file")" "${args[@]}"; then
      rm "$file"
      echo "delivered $(basename "$file") to $host"
    else
      down[$host]=1
    fi
  done
  exit 0
fi

host=$1
shift
input=$(cat)
if [ -n "$(find "$pending" -name '*.json' -print -quit)" ] && jq -e --arg host "$host" 'select(.host == $host)' "$pending"/*.json >/dev/null 2>&1; then
  status=1
else
  status=0
  attempt "$host" "$input" "$@" || status=$?
fi
if [ "$status" -eq 2 ]; then
  exit 2
fi
if [ "$status" -ne 0 ]; then
  jq -n --arg host "$host" --arg input "$input" '{host: $host, args: $ARGS.positional, input: $input}' --args "$@" > "$pending/$(date +%s%N).json"
  echo "queued for $host: $*"
fi
