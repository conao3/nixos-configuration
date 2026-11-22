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
  *)
    echo "agent-board-local: usage: agent-board-local send <t3|bb> <thread> < text | start <t3|bb> <task> | wait <t3|bb> <thread> <runs> | nudge <t3|bb> <thread> <task>" >&2
    exit 2
    ;;
esac
