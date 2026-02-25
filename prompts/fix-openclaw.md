The openclaw service on agent-vm is down. Diagnose and fix it.

# Connection

- SSH to agent-vm: `ssh -p 2222 conao@localhost`
- User: conao

# Target service

The systemd user service `openclaw-gateway` is the target.

- Status: `systemctl --user status openclaw-gateway`
- Logs: `journalctl --user -u openclaw-gateway --no-pager -n 100`
- Restart: `systemctl --user restart openclaw-gateway`

# Config files

- Main config: `~/.openclaw/openclaw.json`
- Environment variables: `~/.openclaw/.env` (managed by sops)
- Auth profiles: `~/.openclaw/agents/main/agent/auth-profiles.json`

# Known failure patterns

## Invalid openclaw.json schema

openclaw version upgrades can change the config file schema.
Logs show `Config invalid` or `Invalid input: expected ...`.

Fix: use jq to correct the field. Restart with `systemctl --user restart openclaw-gateway`.

Past incidents:
- `agents.defaults.heartbeat.session` was an object but a string was expected. Fixed with `jq '.agents.defaults.heartbeat.session = "global"'`.
- `models.providers.ollama` had `apiType` (unrecognized key) and was missing `models` array (expected array, received undefined). Fixed by removing `apiType` and adding `"models": []`. The activation script in home.nix also needed the same fix to prevent recurrence on redeploy.

## Auth profile not configured

Logs show authentication errors. Check auth-profiles.json.

Fix: run `openclaw onboard --auth-choice openai-codex`.

# Diagnostic steps

1. `systemctl --user status openclaw-gateway` - check service state and restart count
2. `journalctl --user -u openclaw-gateway --no-pager -n 100` - check error messages
3. Fix config files based on error messages
4. `systemctl --user restart openclaw-gateway`
5. Wait a few seconds, then check status again to confirm no crash loop
6. Check detailed log at `/tmp/openclaw/openclaw-<date>.log` if needed

# Post-fix verification

After fixing and restarting, verify that:
- Service stays `active (running)` without entering crash loop
- Telegram provider starts: look for `[telegram] [default] starting provider`
- Messages are delivered: look for `[telegram] sendMessage ok`
- Delivery recovery completes: look for `[delivery-recovery] Delivery recovery complete`

Note: `sendChatAction failed: Network request failed` errors are non-critical (typing indicator only) and do not affect message delivery.

A long crash loop can cause delivery entries to accumulate. After recovery, logs may show `Recovery time budget exceeded — N entries deferred to next restart`. These are processed gradually (2 per restart) and resolve over time.

# NixOS config

Service definition is in `hosts/agent-vm/home.nix` in this repository.
If a persistent config fix is needed, update the activation script in home.nix as well. Always check that the runtime fix and the activation script are consistent.

To apply NixOS configuration changes:
- Host OS: `make switch`
- agent-vm: `make vm-agent-switch`
