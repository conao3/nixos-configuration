#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: t3-thread-monitor [--interval SECONDS] THREAD_ID

Watch the latest run of a local T3 Code thread, printing status changes.
The polling interval defaults to 10 seconds.
Exit 0 on completion, 1 on a failed run or read error, or 2 on invalid usage.
EOF
}

die() {
  printf 't3-thread-monitor: %s\n' "$1" >&2
  exit "${2:-1}"
}

interval=10
while (( $# > 0 )); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --interval)
      [[ ${2:-} =~ ^[1-9][0-9]*$ ]] || die '--interval needs a positive integer in seconds' 2
      interval=$2
      shift 2
      ;;
    --) shift; break ;;
    -*) die "unknown option: $1" 2 ;;
    *) break ;;
  esac
done
[[ $# == 1 && -n $1 ]] || die 'specify one thread ID (see --help)' 2
thread_id=$1
previous=

while true; do
  if ! state=$(t3 thread show --json --messages 0 -- "$thread_id" | jq -er --arg id "$thread_id" '
    .thread
    | select(.threadId == $id and (.status | type) == "string" and (.pendingRequestCount | type) == "number")
    | [.status, .pendingRequestCount]
    | @tsv
  '); then
    die "could not read status for $thread_id"
  fi
  IFS=$'\t' read -r status pending <<< "$state"

  if [[ $state != "$previous" ]]; then
    printf '%s %s %s (pending requests: %s)\n' "$(date --iso-8601=seconds)" "$thread_id" "$status" "$pending"
    previous=$state
  fi

  case "$status" in
    completed) exit 0 ;;
    interrupted|failed|cancelled|rolled_back) exit 1 ;;
    idle|preparing|queued|starting|running|waiting) sleep "$interval" ;;
    *) die "unrecognized thread status: $status" ;;
  esac
done
