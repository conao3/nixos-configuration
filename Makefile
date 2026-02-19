all:

.PHONY: update
update:
	nix flake update
	nix flake lock --override-input nixpkgs github:NixOS/nixpkgs/$$(curl -sL https://raw.githubusercontent.com/numtide/llm-agents.nix/main/flake.lock | jq -r '.nodes.nixpkgs.locked.rev')
