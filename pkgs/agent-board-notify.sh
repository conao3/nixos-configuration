state=${XDG_STATE_HOME:-$HOME/.local/state}/agent-board
mkdir -p "$state"
cursor_file=$state/notify.cursor
muse_thread_file=$state/notify.muse-thread
args=(tail work/ --json)
if [ -s "$cursor_file" ]; then
  args+=(--after "$(cat "$cursor_file")")
fi

to_muse() {
  local text="[helios] [factory] board のタスク #$1 が $2 になった。$AGENT_BOARD_VIEW/?thread=$1
vb read $1 でスレッドを読み、completed なら結果を、blocked なら質問と選択肢を、failed なら理由を、パパに短く伝えて。パパは board のタスクへの返信で答えるので、board には書き込まないで。"
  if [ -s "$muse_thread_file" ]; then
    musewire chat send-message --thread-id "$(cat "$muse_thread_file")" --text "$text"
  else
    local sent
    sent=$(musewire chat send-message --thread-id new --text "$text")
    echo "$sent"
    jq -er '.ThreadId' <<<"$sent" > "$muse_thread_file"
  fi
}

to_agent() {
  local text="[factory] Board task #$1, which you created, is now $2. $AGENT_BOARD_VIEW/?thread=$1
Run: BOARD_URL=$BOARD_URL vb read $1
If it is completed, check the result and decide whether to queue follow-up tasks. If it is blocked, answer it with vb reply $1 \"<answer>\" or ask the owner. If it is failed, decide whether to reopen it with vb tasks reopen $1."
  case "$3" in
    t3) t3 thread send "$4" "$text" ;;
    bb) "$AGENT_BOARD_BB" thread tell "$4" --mode auto "$text" ;;
  esac
}

vb "${args[@]}" | while read -r event; do
  type=$(jq -r '.type' <<<"$event")
  case "$type" in
    task.completed | task.blocked | task.failed)
      task=$(jq -r '.payload.id' <<<"$event")
      root=$(vb read "$task" --json | jq -c '.message | {state: .task.state, notify: (.labels.notify // "muse")}')
      now=$(jq -r '.state' <<<"$root")
      notify=$(jq -r '.notify' <<<"$root")
      if [ "$type" = "task.${now}" ]; then
        if [ "$notify" = muse ]; then
          if [ -n "${AGENT_BOARD_MUSE:-}" ]; then
            to_muse "$task" "$now"
            echo "notified muse: task $task $now"
          fi
        else
          target=${notify%%:*}
          thread=${notify#*:}
          if [ "${target#*@}" = "$AGENT_BOARD_HOST" ]; then
            to_agent "$task" "$now" "${target%@*}" "$thread"
            echo "notified $notify: task $task $now"
          fi
        fi
      fi
      ;;
  esac
  jq -r '.cursor' <<<"$event" > "$cursor_file"
done
