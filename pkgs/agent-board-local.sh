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
  nudge)
    exec agent-board-worker nudge "$2" "$3" "$4"
    ;;
  *)
    echo "agent-board-local: usage: agent-board-local send <t3|bb> <thread> < text | nudge <t3|bb> <thread> <task>" >&2
    exit 2
    ;;
esac
