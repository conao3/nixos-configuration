all:

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

.PHONY: vm-agent-switch
vm-agent-switch:
	NIX_SSHOPTS="-p 2222" nixos-rebuild test --flake .#agent-vm --target-host conao@localhost --sudo
