{
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  t3 = inputs.llm-agents.packages.${system}.t3code;
in
{
  # T3 Code の headless server 常駐 (他ホストの T3 から接続先ノードとして使う)。
  # 組み込みの `t3 service install` は固定ランタイムの検証に失敗する (nix 環境) ため systemd で直接管理する。
  # デスクトップアプリの 3773 と衝突しないよう 3774 に bind し、Tailscale Serve で 8443 に公開する
  systemd.user.services.t3code-server = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "T3 Code headless server (Tailscale Serve :8443)";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${t3}/bin/t3 serve --port 3774 --tailscale-serve --tailscale-serve-port 8443 %h";
      # provider (claude / codex) と git を子プロセスから呼ぶため user の PATH を渡す
      Environment = [ "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
