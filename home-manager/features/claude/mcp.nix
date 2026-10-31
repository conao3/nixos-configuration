{ pkgs, ... }:
{
  programs.agents.mcpServers = {
    # drawio-mcp-server を systemd user service (drawio-mcp) として常駐させ、全エージェントで
    # 1 プロセスを共有する。stdio でセッションごとに spawn すると拡張用 WebSocket ポート 3333 が
    # 衝突するため常駐にしている。ブラウザ拡張は ws://localhost:3333 で同 service に接続する
    drawio = {
      url = "http://127.0.0.1:3733/mcp";
      service = {
        description = "Draw.io MCP server (shared, http transport)";
        execStart = "${
          pkgs.callPackage ../../../pkgs/drawio-mcp-server.nix { }
        }/bin/drawio-mcp-server --transport http --http-port 3733 --host 127.0.0.1";
      };
    };
    linear.url = "https://mcp.linear.app/mcp";
    penpot.url = "https://design.penpot.app/mcp/stream?userToken=\${PENPOT_MCP_KEY}";
    devin = {
      url = "https://mcp.devin.ai/mcp";
      bearerTokenEnvVar = "DEVIN_API_KEY";
    };
    freee.url = "https://mcp.freee.co.jp/mcp";
    flovia = {
      url = "https://api.flovia.dev/mcp";
      bearerTokenFile = "~/.config/flovia/key";
      enableFor = [ "claude" ];
    };
  };
}
