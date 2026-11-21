state=${XDG_STATE_HOME:-$HOME/.local/state}/agent-board
mkdir -p "$state"
cursor_file=$state/replies.cursor
args=(tail work/ --json)
if [ -s "$cursor_file" ]; then
  args+=(--after "$(cat "$cursor_file")")
fi
vb "${args[@]}" | while read -r event; do
  if jq -e '.type == "message.posted" and .message.re != null and .message.by.profile == null' <<<"$event" >/dev/null; then
    task=$(jq -r '.message.re' <<<"$event")
    root=$(vb read "$task" --json | jq -c '.message | {host: .labels.host, harness: .labels.harness, thread: .labels.thread, state: .task.state}')
    host=$(jq -r '.host // empty' <<<"$root")
    harness=$(jq -r '.harness // empty' <<<"$root")
    thread=$(jq -r '.thread // empty' <<<"$root")
    task_state=$(jq -r '.state // empty' <<<"$root")
    if [ "$host" = "$AGENT_BOARD_HOST" ] && [ -n "$thread" ]; then
      echo "reply on task $task ($task_state) for $harness thread $thread"
      case "$task_state" in
        blocked) vb tasks unblock "$task" ;;
        failed) vb tasks reopen "$task" ;;
        completed | canceled | claimed) agent-board-worker nudge "$harness" "$thread" "$task" ;;
      esac
    fi
  fi
  jq -r '.cursor' <<<"$event" > "$cursor_file"
done
