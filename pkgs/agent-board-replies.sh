state=${XDG_STATE_HOME:-$HOME/.local/state}/agent-board
mkdir -p "$state"
cursor_file=$state/replies.cursor
args=(tail work/ --json)
if [ -s "$cursor_file" ]; then
  args+=(--after "$(cat "$cursor_file")")
fi
vb "${args[@]}" | while read -r event; do
  if jq -e '.type == "message.posted" and .message.re != null' <<<"$event" >/dev/null; then
    task=$(jq -r '.message.re' <<<"$event")
    root=$(vb read "$task" --json | jq -c '.message | {host: .labels.host, harness: .labels.harness, thread: .labels.thread, state: .task.state, creator: .by.actor}')
    host=$(jq -r '.host // empty' <<<"$root")
    harness=$(jq -r '.harness // empty' <<<"$root")
    thread=$(jq -r '.thread // empty' <<<"$root")
    task_state=$(jq -r '.state // empty' <<<"$root")
    creator=$(jq -r '.creator' <<<"$root")
    if [ -n "$host" ] && [ -n "$thread" ] && jq -e --arg creator "$creator" '.message.by.profile == null or .message.by.actor == $creator' <<<"$event" >/dev/null; then
      echo "reply on task $task ($task_state) for $harness thread $thread"
      case "$task_state" in
        blocked) vb tasks unblock "$task" ;;
        failed) vb tasks reopen "$task" ;;
        completed | canceled | claimed) agent-board-deliver "$host" nudge "$harness" "$thread" "$task" </dev/null ;;
      esac
    fi
  fi
  jq -r '.cursor' <<<"$event" > "$cursor_file"
done
