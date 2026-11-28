{
  user = "conao";
  modules =
    import ./full.nix
    ++ import ./full-gui.nix
    ++ [
      (import ../home-manager/features/sanimmerse-agent.nix { anki = false; })
      (import ../home-manager/features/sellaite-dashboard.nix { host = "helios"; })
      ../home-manager/features/t3code-server.nix
      (import ../home-manager/features/gh-lookout.nix { serve = true; })
      (import ../home-manager/features/agent-board.nix {
        host = "helios";
        boardUrl = "http://127.0.0.1:4100/api/board";
        serveOn = "conao-nixos-helios.tail6dd115.ts.net";
        hosts = [
          "helios"
          "eos"
        ];
        slots = {
          helios = 5;
          eos = 5;
          claudecodeweb = 10;
        };
      })
    ];
}
