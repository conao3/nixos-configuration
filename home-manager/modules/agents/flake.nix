{
  description = "home-manager module for multi-instance coding agents";

  outputs = _: {
    homeManagerModules = rec {
      agents = ./default.nix;
      default = agents;
    };
  };
}
