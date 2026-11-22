{
  host,
  boardUrl,
  harnesses,
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
  local = pkgs.writeShellApplication {
    name = "agent-board-local";
    runtimeInputs = [
      t3
      worker
    ];
    text = ''
      export BOARD_URL=${boardUrl} AGENT_BOARD_HOST=${host} AGENT_BOARD_BB=${
        inputs.llm-agents.packages.${system}.bb-app
      }/bin/bb BOARD_PROFILE=replies-${host}
    ''
    + builtins.readFile ../../pkgs/agent-board-local.sh;
  };
  deliver = pkgs.writeShellApplication {
    name = "agent-board-deliver";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.jq
      pkgs.openssh
      local
    ];
    text = builtins.readFile ../../pkgs/agent-board-deliver.sh;
  };
  replies = pkgs.writeShellApplication {
    name = "agent-board-replies";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      vb
      deliver
    ];
    text = builtins.readFile ../../pkgs/agent-board-replies.sh;
  };
  notify = pkgs.writeShellApplication {
    name = "agent-board-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      vb
      deliver
    ];
    text = builtins.readFile ../../pkgs/agent-board-notify.sh;
  };
  viewUrl = if serveOn != null then "https://${serveOn}" else lib.removeSuffix "/api/board" boardUrl;
  environment = [
    "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin"
    "BOARD_URL=${boardUrl}"
    "AGENT_BOARD_BB=${inputs.llm-agents.packages.${system}.bb-app}/bin/bb"
    "AGENT_BOARD_HOST=${host}"
    "AGENT_BOARD_HOSTS=${builtins.toJSON hosts}"
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
  home.packages = [
    vb
    local
  ];
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
      # 人がタスクのスレッドに返信したら、そのタスクを担当したエージェントのスレッドに続きを渡す。
      # 人待ちは解除し、失敗は着手可に戻して runner に取らせ、完了済みはスレッドへ直接送る
      agent-board-replies = {
        Unit = {
          Description = "Vercel Board replies: hand the replies on work/ tasks to the agent thread on its host";
          After = [
            "network-online.target"
            "agent-board.service"
          ];
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
      agent-board-notify = {
        Unit = {
          Description = "Vercel Board notify: tell the creator of a work/ task when it is completed, blocked or failed";
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
            "AGENT_BOARD_VIEW=${viewUrl}"
          ];
          Restart = "always";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };
      agent-board-deliver-retry = {
        Unit.Description = "Vercel Board deliver: retry the notices and replies that could not reach their host";
        Service = {
          Type = "oneshot";
          ExecStart = "${deliver}/bin/agent-board-deliver --retry";
          Environment = environment;
        };
      };
    }
    // builtins.listToAttrs (map runnerService harnesses)
  );
  systemd.user.timers = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && serveOn != null) {
    agent-board-deliver-retry = {
      Unit.Description = "Vercel Board deliver: retry every minute";
      Timer = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
