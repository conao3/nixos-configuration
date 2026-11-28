{
  host,
  boardUrl,
  serveOn ? null,
  hosts ? [ ],
  slots ? { },
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
  bb = "${inputs.llm-agents.packages.${system}.bb-app}/bin/bb";
  server = pkgs.writeShellApplication {
    name = "agent-board-server";
    runtimeInputs = [
      pkgs.python3
      t3
      vb
    ];
    text = "exec python3 ${../../pkgs/agent-board-server.py}";
  };
  viewUrl = if serveOn != null then "https://${serveOn}" else lib.removeSuffix "/api/board" boardUrl;
  environment = [
    "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
    "BOARD_URL=${boardUrl}"
    "BOARD_PROFILE=server-${host}"
    "AGENT_BOARD_HOST=${host}"
    "AGENT_BOARD_HOSTS=${pkgs.writeText "agent-board-hosts.json" (builtins.toJSON hosts)}"
    "AGENT_BOARD_SLOTS=${
      pkgs.writeText "agent-board-slots.json" (
        builtins.toJSON (lib.genAttrs (hosts ++ [ "claudecodeweb" ]) (h: slots.${h} or 5))
      )
    }"
    "AGENT_BOARD_VIEW=${viewUrl}"
    "AGENT_BOARD_BB=${bb}"
    "AGENT_BOARD_CLAUDE_CONFIG_DIR=%h/.agents/.claude.conao3"
  ];
in
{
  home.packages = [ vb ];
  home.sessionVariables.BOARD_URL = boardUrl;

  # Vercel Board (エージェントの仕事の列)。board は 1 ホストの `vb serve` を Tailscale Serve で tailnet に出し、
  # board のホストの agent-board-server が、hosts のどれかを host のラベルに持つ着手可のタスクを、ホストごとに同時に slots のそのホストの件数 (slots に無いホストは 5 件) まで取り、harness のラベル (無ければ bb にして記録する) のエージェントをそのホストで起動する。bb のエージェントは、チャンネル work/<repo> の repo の bb のプロジェクト (無ければ作る) に、新しい worktree で立て、完了したタスクのスレッドを archive する。host=claudecodeweb のタスクは、board のホストの tmux から repo の作業ツリーで claude --cloud を実行して Claude Code web のセッションに渡し、ワーカーの board の返信の最後の行で完了・確認待ち・失敗にする。
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
      # board の管理者。全ホストのタスクの着手と完了、返信の受け渡し、通知を 1 つのプロセスで受け持ち、
      # ほかのホストのエージェントは T3 Code の linked environment と bb の machine で動かす
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
          KillMode = "mixed";
          TimeoutStopSec = 300;
        };
        Install.WantedBy = [ "default.target" ];
      };
    }
  );
}
