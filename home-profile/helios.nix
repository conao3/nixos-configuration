{
  user = "conao";
  modules = import ./full.nix ++ import ./full-gui.nix ++ [
    ../home-manager/features/dev-ca.nix
  ];
}
