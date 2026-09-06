{
  user = "conao";
  modules =
    import ./full.nix
    ++ import ./full-gui.nix
    ++ [
      ../home-manager/features/internal-panel-120hz.nix
    ];
}
