SHELL := bash
.SHELLFLAGS := -o pipefail -c

all:

UNAME_S := $(shell uname -s)
NOM := nix run nixpkgs\#nix-output-monitor --

.PHONY: switch
switch:
ifeq ($(UNAME_S),Darwin)
	sudo -H nix run nix-darwin -- switch --flake . --show-trace |& $(NOM)
else
	sudo nixos-rebuild switch --flake . --log-format internal-json -v 2>&1 | $(NOM) --json
	systemctl --user daemon-reload || true
	systemctl --user restart timers.target || true
	@cat $(HOME)/.claude/settings-warnings.log 2>/dev/null || true
endif

.PHONY: switch-dry-run
switch-dry-run:
ifeq ($(UNAME_S),Darwin)
	sudo -H nix run nix-darwin -- switch --flake . --dry-run --show-trace |& $(NOM)
else
	sudo nixos-rebuild switch --flake . --dry-run --log-format internal-json -v 2>&1 | nom --json
endif

.PHONY: lint
lint:
	nix eval .#nixosConfigurations.agent-vm.config.system.build.toplevel 2>&1 >/dev/null | grep "evaluation warning:" && exit 1 || true

.PHONY: update
update:
	nix flake update --log-format internal-json -v 2>&1 | nom --json
	nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/$$(curl -sL https://raw.githubusercontent.com/numtide/llm-agents.nix/main/flake.lock | jq -r '.nodes.nixpkgs.locked.rev') --log-format internal-json -v 2>&1 | nom --json

MEMORY ?= 4096
CORES ?= 2
DISK_SIZE ?= 100G

.PHONY: edit-secrets
edit-secrets:
	sops secrets/secrets.yaml

.PHONY: vm-agent
vm-agent:
	nix build -L .#nixosConfigurations.conao-nixos-agent.config.system.build.vm --log-format internal-json -v 2>&1 | nom --json
	@if [ -e conao-nixos-agent.qcow2 ]; then \
		QEMU_IMG=$$(nix build --no-link --print-out-paths nixpkgs#qemu-utils)/bin/qemu-img; \
		$$QEMU_IMG resize conao-nixos-agent.qcow2 $(DISK_SIZE); \
	fi
	rm -f /tmp/virtiofsd-dev-repos.sock
	nix run nixpkgs#virtiofsd -- --socket-path=/tmp/virtiofsd-dev-repos.sock --shared-dir=$(HOME)/ghq --sandbox none & \
	VIRTIOFSD_PID=$$!; \
	while [ ! -S /tmp/virtiofsd-dev-repos.sock ]; do sleep 0.1; done; \
	QEMU_OPTS="-m $(MEMORY) -smp $(CORES) -object memory-backend-memfd,id=mem,share=on,size=$(MEMORY)M -machine memory-backend=mem" ./result/bin/run-conao-nixos-agent-vm; \
	kill $$VIRTIOFSD_PID 2>/dev/null || true

.PHONY: vm-agent-switch
vm-agent-switch:
	NIX_SSHOPTS="-p 2222" nixos-rebuild switch --flake .#conao-nixos-agent --target-host conao@localhost --sudo --log-format internal-json -v 2>&1 | nom --json

.PHONY: vm-agent-fix-openclaw
vm-agent-fix-openclaw:
	cat prompts/fix-openclaw.md | claude --dangerously-skip-permissions
