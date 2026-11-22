{
  host,
  boardUrl,
  serveOn ? null,
  hosts ? { },
}:
{
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  version = "0.54.0";
  vb = pkgs.writeShellScriptBin "vb" ''
    exec ${pkgs.nodejs_24}/bin/npx --yes @vercel/board@${version} "$@"
  '';
  t3 = (import ../../pkgs/t3code.nix { inherit inputs pkgs system; }).t3code;
  worker = pkgs.writeShellApplication {
    name = "agent-board-worker";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.hostname
      pkgs.jq
      pkgs.python3
      t3
      vb
    ];
    text = builtins.readFile ../../pkgs/agent-board-worker.sh;
  };
  local = pkgs.writeShellApplication {
    name = "agent-board-local";
    runtimeInputs = [
      t3
      worker
    ];
    text = ''
      export BOARD_URL=${boardUrl} AGENT_BOARD_HOST=${host} AGENT_BOARD_BB=${
        inputs.llm-agents.packages.${system}.bb-app
      }/bin/bb BOARD_PROFILE=local-${host}
    ''
    + builtins.readFile ../../pkgs/agent-board-local.sh;
  };
  server = pkgs.writeShellApplication {
    name = "agent-board-server";
    runtimeInputs = [
      pkgs.openssh
      pkgs.python3
      local
      vb
    ];
    text = "exec python3 ${../../pkgs/agent-board-server.py}";
  };
  viewUrl = if serveOn != null then "https://${serveOn}" else lib.removeSuffix "/api/board" boardUrl;
  environment = [
    "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
    "BOARD_URL=${boardUrl}"
    "AGENT_BOARD_HOSTS=${builtins.toJSON hosts}"
    "AGENT_BOARD_VIEW=${viewUrl}"
    "BOARD_PROFILE=server-${host}"
  ];
in
{
  home.packages = [
    vb
    local
  ];
  home.sessionVariables.BOARD_URL = boardUrl;

  # Vercel Board (エージェントの仕事の列)。board は 1 ホストの `vb serve` を Tailscale Serve で tailnet に出し、
  # board のホストの agent-board-server が、全ホストの host / harness のラベルの付いた着手可のタスクを取ってエージェントを起動する。
  # tailnet への公開は board のホストで一度 `tailscale serve --bg 4100` を実行する (tailscaled が設定を保持する)
  systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    lib.optionalAttrs (serveOn != null) {
      agent-board = {
        Unit = {
          Description = "Vercel Board (vb serve, Tailscale Serve :443)";
          After = [ "network-online.target" ];
        };
        Service = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/share/agent-board";
          WorkingDirectory = "%h/.local/share/agent-board";
          ExecStart = "${vb}/bin/vb serve --port 4100 --dir %h/.local/share/agent-board/.board --no-open --tailscale ${serveOn}";
          Environment = [
            "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
      # board の管理者。全ホストのタスクの着手と完了、返信の受け渡し、知らせを 1 つのプロセスで受け持ち、
      # ほかのホストのエージェントは ssh で agent-board-local を実行して動かす
      agent-board-server = {
        Unit = {
          Description = "Vercel Board server: run the work/ tasks of every host, hand replies to their threads and tell their creators";
          After = [
            "network-online.target"
            "agent-board.service"
          ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = "${server}/bin/agent-board-server";
          Environment = environment;
          Restart = "always";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };
    }
  );
}
