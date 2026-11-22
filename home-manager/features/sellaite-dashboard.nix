{ host }:
{
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  sellaite = inputs.sellaite.packages.${system}.default;
  publicOrigin = "https://conao-nixos-${host}.tail6dd115.ts.net:8731";
in
{
  home.packages = [ sellaite ];

  # sellaite (conao3/rust-sellaite) のダッシュボード。127.0.0.1:8730 で待ち、tailnet へは `tailscale serve --bg --https=8731 http://127.0.0.1:8730` を
  # 各ホストで一度実行して出す (tailscaled が設定を保持する)。`Tailscale-User-Login` が --allowed-logins に無い要求は 403 になる
  systemd.user.services.sellaite-dashboard = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "sellaite dashboard (Tailscale Serve :8731)";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = ''${sellaite}/bin/sellaite dashboard start-dashboard --token-file "%S/sellaite/dashboard-token" --public-origins ${publicOrigin} --allowed-logins conao3@gmail.com'';
      StateDirectory = "sellaite";
      StateDirectoryMode = "0700";
      # The startup URL contains the reusable credential.
      StandardOutput = "null";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
