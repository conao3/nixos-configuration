state=${XDG_STATE_HOME:-$HOME/.local/state}/agent-board
mkdir -p "$state"
cursor_file=$state/notify.cursor
muse_thread_file=$state/notify.muse-thread
args=(tail work/ --json)
if [ -s "$cursor_file" ]; then
  args+=(--after "$(cat "$cursor_file")")
fi
vb "${args[@]}" | while read -r event; do
  type=$(jq -r '.type' <<<"$event")
  case "$type" in
    task.blocked | task.failed)
      task=$(jq -r '.payload.id' <<<"$event")
      now=$(vb read "$task" --json | jq -r '.message.task.state')
      if [ "$type" = "task.${now}" ]; then
        case "$now" in
          blocked) what="人待ち (オーナーの判断を待っている)" ;;
          failed) what="失敗" ;;
        esac
        text="[helios] [factory] board のタスク #$task が$whatになった。$AGENT_BOARD_VIEW/?thread=$task
vb read $task でスレッドを読み、人待ちなら質問と選択肢を、失敗なら理由を、パパに短く伝えて。パパは board のタスクへの返信で答えるので、board には書き込まないで。"
        if [ -s "$muse_thread_file" ]; then
          musewire chat send-message --thread-id "$(cat "$muse_thread_file")" --text "$text"
        else
          sent=$(musewire chat send-message --thread-id new --text "$text")
          echo "$sent"
          jq -er '.ThreadId' <<<"$sent" > "$muse_thread_file"
        fi
        echo "notified muse: task $task $now"
      fi
      ;;
  esac
  jq -r '.cursor' <<<"$event" > "$cursor_file"
done
