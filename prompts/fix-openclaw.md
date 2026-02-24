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

## Auth profile not configured

Logs show authentication errors. Check auth-profiles.json.

Fix: run `openclaw onboard --auth-choice openai-codex`.

# Diagnostic steps

1. `systemctl --user status openclaw-gateway` - check service state and restart count
2. `journalctl --user -u openclaw-gateway --no-pager -n 100` - check error messages
3. Fix config files based on error messages
4. `systemctl --user restart openclaw-gateway`
5. Wait a few seconds, then check status again to confirm no crash loop

# NixOS config

Service definition is in `hosts/agent-vm/home.nix` in this repository.
If a persistent config fix is needed, update the activation script in home.nix as well.

To apply NixOS configuration changes:
- Host OS: `make switch`
- agent-vm: `make vm-agent-switch`
