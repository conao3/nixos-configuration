all:

.PHONY: update
update:
	nix flake update
	nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/$$(curl -sL https://raw.githubusercontent.com/numtide/llm-agents.nix/main/flake.lock | jq -r '.nodes.nixpkgs.locked.rev')

MEMORY ?= 4096
CORES ?= 2

.PHONY: vm-zeroclaw
vm-zeroclaw:
	nix build -L .#nixosConfigurations.zeroclaw-vm.config.system.build.vm
	QEMU_OPTS="-m $(MEMORY) -smp $(CORES)" ./result/bin/run-nixos-vm
