all:

.PHONY: lint
lint:
	nix eval .#nixosConfigurations.agent-vm.config.system.build.toplevel 2>&1 >/dev/null | grep "evaluation warning:" && exit 1 || true

.PHONY: update
update:
	nix flake update
	nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/$$(curl -sL https://raw.githubusercontent.com/numtide/llm-agents.nix/main/flake.lock | jq -r '.nodes.nixpkgs.locked.rev')

MEMORY ?= 4096
CORES ?= 2

.PHONY: vm-agent-edit-secrets
vm-agent-edit-secrets:
	sops hosts/agent-vm/secrets/secrets.yaml

.PHONY: vm-agent
vm-agent:
	nix build -L .#nixosConfigurations.agent-vm.config.system.build.vm
	rm -f /tmp/virtiofsd-dev-repos.sock
	nix run nixpkgs#virtiofsd -- --socket-path=/tmp/virtiofsd-dev-repos.sock --shared-dir=$(HOME)/dev/repos --sandbox none & \
	VIRTIOFSD_PID=$$!; \
	sleep 1; \
	QEMU_OPTS="-m $(MEMORY) -smp $(CORES)" ./result/bin/run-nixos-vm; \
	kill $$VIRTIOFSD_PID 2>/dev/null || true

.PHONY: vm-agent-tunnel
vm-agent-tunnel:
	ssh -p 2222 -N conao@localhost \
	  -L 18789:127.0.0.1:18789 \
	  -L 18792:127.0.0.1:18792 \
	  -L 18701:127.0.0.1:18701

.PHONY: vm-agent-switch
vm-agent-switch:
	sudo nixos-rebuild switch --flake .#agent-vm

.PHONY: vm-agent-switch-ssh
vm-agent-switch-ssh:
	NIX_SSHOPTS="-p 2222" nixos-rebuild switch --flake .#agent-vm --target-host conao@localhost --sudo
