.PHONY: dev frontend backend

dev:
	nix develop . --command sh -c 'set -euo pipefail; export DASHBOARD_BACKEND_HOST=127.0.0.1 DASHBOARD_BACKEND_PORT=9411 DASHBOARD_DEV_BACKEND_PORT=9411; python3 backend.py & backend_pid=$$!; trap "kill $$backend_pid 2>/dev/null || true" EXIT INT TERM; cd frontend; [ -d node_modules ] || pnpm install --frozen-lockfile; pnpm dev'

frontend:
	nix develop .#frontend --command sh -c 'cd frontend; [ -d node_modules ] || pnpm install --frozen-lockfile; pnpm dev'

backend:
	nix develop .#backend --command sh -c 'export DASHBOARD_BACKEND_HOST=127.0.0.1 DASHBOARD_BACKEND_PORT=9411; python3 backend.py'
