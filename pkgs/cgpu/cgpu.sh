usage() {
  echo "Usage: cgpu <service> <command> [options]"
  echo
  echo "Run self-hosted models on GPU services. Each service has its own commands:"
  echo "  cgpu <service> --help"
  echo
  echo "Services:"
  for service in "$SERVICES_DIR"/*; do
    echo "  $(basename "$service")"
  done
}

service="${1:-}"
case "$service" in
  "" | -h | --help | help)
    usage
    exit 0
    ;;
esac
shift
[ -x "$SERVICES_DIR/$service" ] || {
  echo "cgpu: error: unknown service '$service'" >&2
  usage >&2
  exit 2
}
exec "$SERVICES_DIR/$service" "$@"
