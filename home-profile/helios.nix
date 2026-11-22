{
  user = "conao";
  modules =
    import ./full.nix
    ++ import ./full-gui.nix
    ++ [
      ../home-manager/features/cherry-studio.nix
      ../home-manager/features/codex-desktop.nix
      ../home-manager/features/dev-ca.nix
      (import ../home-manager/features/sellaite-dashboard.nix { host = "helios"; })
      ../home-manager/features/t3code-server.nix
      (import ../home-manager/features/agent-board.nix {
        host = "helios";
        boardUrl = "http://127.0.0.1:4100/api/board";
        serveOn = "conao-nixos-helios.tail6dd115.ts.net";
        hosts = {
          helios = [ "t3" ];
          eos = [
            "bb"
            "t3"
          ];
        };
      })
    ];
}
