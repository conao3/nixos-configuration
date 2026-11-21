{
  user = "conao";
  modules =
    import ./full.nix
    ++ import ./full-gui.nix
    ++ [
      ../home-manager/features/battery-warning.nix
      ../home-manager/features/internal-panel-120hz.nix
      ../home-manager/features/demo-mode.nix
      (import ../home-manager/features/agent-board.nix {
        host = "eos";
        boardUrl = "https://conao-nixos-helios.tail6dd115.ts.net/api/board";
        harnesses = [
          "bb"
          "t3"
        ];
      })
    ];
}
