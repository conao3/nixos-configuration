{
  pkgs,
  lib,
  inputs,
  system,
  ...
}:
let
  inherit
    (import ./common.nix {
      inherit
        pkgs
        lib
        inputs
        system
        ;
    })
    llmAgents
    aliasSpecs
    codexBin
    wrapperPackages
    cursorProfilePackages
    sakanaProfilePackages
    ;
in
{
  imports = [
    ./files.nix
    ./dirs.nix
    ./settings.nix
    ./share.nix
    ./codex.nix
    ./cursor.nix
  ];

  home.packages =
    wrapperPackages
    ++ cursorProfilePackages
    ++ sakanaProfilePackages
    ++ [
      inputs.nix-claude-code.packages.${system}.default
      llmAgents.codex
    ]
    ++ map (spec: pkgs.writeShellScriptBin spec.executableName ''exec ${spec.target} "$@"'') aliasSpecs;

  programs.git.ignores = [
    ".claude"
    ".claude-dev"
    ".codex"
  ];

  programs.zsh.initContent = lib.mkAfter ''
    codex() {
      AGMSG_REAL_CODEX=${codexBin} \
        "$HOME/.agents/skills/agmsg/scripts/drivers/types/codex/codex-shim.sh" "$@"
    }
  '';
  # drawio-mcp-server 常駐 service。各エージェントは common.nix の mcpServers.drawio
  # (http://127.0.0.1:3733/mcp) でこの 1 プロセスを共有する。stdio でセッションごとに
  # spawn すると拡張用 WebSocket ポート 3333 が衝突するため常駐にしている
  systemd.user.services.drawio-mcp = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Draw.io MCP server (shared, http transport)";
    Service = {
      ExecStart = "${
        pkgs.callPackage ../../../pkgs/drawio-mcp-server.nix { }
      }/bin/drawio-mcp-server --transport http --http-port 3733 --host 127.0.0.1";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
