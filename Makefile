all:

.PHONY: lint
lint:
	nix eval .#nixosConfigurations.agent-vm.config.system.build.toplevel 2>&1 >/dev/null | grep "evaluation warning:" && exit 1 || true

.PHONY: vm-agent-edit-secrets
vm-agent-edit-secrets:
	sops hosts/agent-vm/secrets/secrets.yaml

.PHONY: update
update:
	nix flake update
	nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/$$(curl -sL https://raw.githubusercontent.com/numtide/llm-agents.nix/main/flake.lock | jq -r '.nodes.nixpkgs.locked.rev')

MEMORY ?= 4096
CORES ?= 2

.PHONY: vm-agent
vm-agent:
	nix build -L .#nixosConfigurations.agent-vm.config.system.build.vm
	QEMU_OPTS="-m $(MEMORY) -smp $(CORES)" ./result/bin/run-nixos-vm

.PHONY: vm-agent-tunnel
vm-agent-tunnel:
	ssh -p 2222 -L 18789:127.0.0.1:18789 -N conao@localhost

.PHONY: vm-agent-switch
vm-agent-switch:
	NIX_SSHOPTS="-p 2222" nixos-rebuild test --flake .#agent-vm --target-host conao@localhost --sudo; \
	ret=$$?; \
	if [ $$ret -eq 4 ]; then \
		echo "Warning: nix-store.mount could not be restarted (expected in VM), configuration applied"; \
	elif [ $$ret -ne 0 ]; then \
		exit $$ret; \
	fi
