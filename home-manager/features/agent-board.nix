{
  host,
  boardUrl,
  harnesses,
  serveOn ? null,
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
      t3
      vb
    ];
    text = builtins.readFile ../../pkgs/agent-board-worker.sh;
  };
  runner =
    harness:
    pkgs.writeShellApplication {
      name = "agent-board-runner-${harness}";
      runtimeInputs = [
        pkgs.jq
        vb
        worker
      ];
      text = ''
        from=()
        while read -r owner; do
          from+=(--from "$owner")
        done < <(vb actors --json | jq -r '.actors[] | select(.kind == "person") | .id')
        exec vb tasks run --ready work/ --label host=${host} --label harness=${harness} "''${from[@]}" --wait 10m --json -- agent-board-worker run ${harness}
      '';
    };
  replies = pkgs.writeShellApplication {
    name = "agent-board-replies";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      vb
      worker
    ];
    text = builtins.readFile ../../pkgs/agent-board-replies.sh;
  };
  notify = pkgs.writeShellApplication {
    name = "agent-board-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      vb
    ];
    text = builtins.readFile ../../pkgs/agent-board-notify.sh;
  };
  environment = [
    "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
    "BOARD_URL=${boardUrl}"
    "AGENT_BOARD_BB=${inputs.llm-agents.packages.${system}.bb-app}/bin/bb"
    "AGENT_BOARD_HOST=${host}"
  ];
  runnerService = harness: {
    name = "agent-board-runner-${harness}";
    value = {
      Unit = {
        Description = "Vercel Board runner: tasks labelled host=${host} harness=${harness}";
        After = [ "network-online.target" ] ++ lib.optional (serveOn != null) "agent-board.service";
        StartLimitIntervalSec = 0;
      };
      Service = {
        ExecStart = "${runner harness}/bin/agent-board-runner-${harness}";
        Environment = environment ++ [ "BOARD_PROFILE=runner-${host}-${harness}" ];
        Restart = "always";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
in
{
  home.packages = [ vb ];
  home.sessionVariables.BOARD_URL = boardUrl;

  # Vercel Board (エージェントの仕事の列)。board は 1 ホストの `vb serve` を Tailscale Serve で tailnet に出し、
  # 各ホストの runner が、自分宛てのラベル (host / harness) の付いた着手可のタスクを取ってエージェントを起動する。
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
      agent-board-notify = {
        Unit = {
          Description = "Vercel Board notify: tell Muse when a work/ task is blocked or failed";
          After = [
            "network-online.target"
            "agent-board.service"
          ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = "${notify}/bin/agent-board-notify";
          Environment = environment ++ [
            "BOARD_PROFILE=notify-${host}"
            "AGENT_BOARD_VIEW=https://${serveOn}"
          ];
          Restart = "always";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };
    }
    // {
      # 人がタスクのスレッドに返信したら、そのタスクを担当したエージェントのスレッドに続きを渡す。
      # 人待ちは解除し、失敗は着手可に戻して runner に取らせ、完了済みはスレッドへ直接送る
      agent-board-replies = {
        Unit = {
          Description = "Vercel Board replies: hand the owner's replies on host=${host} tasks to the agent thread";
          After = [ "network-online.target" ] ++ lib.optional (serveOn != null) "agent-board.service";
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = "${replies}/bin/agent-board-replies";
          Environment = environment ++ [ "BOARD_PROFILE=replies-${host}" ];
          Restart = "always";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };
    }
    // builtins.listToAttrs (map runnerService harnesses)
  );
}
