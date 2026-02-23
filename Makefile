all:

.PHONY: switch
switch:
	sudo nixos-rebuild switch --flake .

.PHONY: lint
lint:
	nix eval .#nixosConfigurations.agent-vm.config.system.build.toplevel 2>&1 >/dev/null | grep "evaluation warning:" && exit 1 || true

.PHONY: update
update:
	nix flake update
	nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/$$(curl -sL https://raw.githubusercontent.com/numtide/llm-agents.nix/main/flake.lock | jq -r '.nodes.nixpkgs.locked.rev')

MEMORY ?= 4096
CORES ?= 2

.PHONY: edit-secrets
edit-secrets:
	sops secrets/secrets.yaml

.PHONY: vm-agent
vm-agent:
	nix build -L .#nixosConfigurations.conao-nixos-agent.config.system.build.vm
	rm -f /tmp/virtiofsd-dev-repos.sock
	nix run nixpkgs#virtiofsd -- --socket-path=/tmp/virtiofsd-dev-repos.sock --shared-dir=$(HOME)/dev/repos --sandbox none & \
	VIRTIOFSD_PID=$$!; \
	sleep 1; \
	QEMU_OPTS="-m $(MEMORY) -smp $(CORES) -object memory-backend-memfd,id=mem,share=on,size=$(MEMORY)M -machine memory-backend=mem" ./result/bin/run-conao-nixos-agent-vm; \
	kill $$VIRTIOFSD_PID 2>/dev/null || true

.PHONY: vm-agent-switch
vm-agent-switch:
	NIX_SSHOPTS="-p 2222" nixos-rebuild switch --flake .#conao-nixos-agent --target-host conao@localhost --sudo
