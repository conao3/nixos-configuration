case "${1:-}" in
  send)
    text=$(cat)
    case "$2" in
      t3) t3 thread send "$3" "$text" ;;
      bb) "$AGENT_BOARD_BB" thread tell "$3" --mode auto "$text" ;;
      *)
        echo "agent-board-local: unknown harness $2" >&2
        exit 2
        ;;
    esac
    ;;
  start | wait | nudge)
    exec agent-board-worker "$@"
    ;;
  models)
    exec "$AGENT_BOARD_BB" provider models "$2" --json
    ;;
  *)
    echo "agent-board-local: usage: agent-board-local send <t3|bb> <thread> < text | start <t3|bb> <task> <model args> | wait <t3|bb> <thread> <runs> | nudge <t3|bb> <thread> <task> <model args> | models <bb provider>" >&2
    exit 2
    ;;
esac
