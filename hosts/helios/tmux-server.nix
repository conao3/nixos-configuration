{
  pkgs,
  ...
}:
{
  systemd.user.services.tmux-server = {
    description = "tmux server (clean argv, no session names)";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecCondition = "${pkgs.writeShellScript "tmux-server-cond" ''
        set -eu
        export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
        ! ${pkgs.tmux}/bin/tmux ls >/dev/null 2>&1
      ''}";
      ExecStart = "${pkgs.writeShellScript "tmux-server-start" ''
        set -eu
        export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
        exec ${pkgs.tmux}/bin/tmux -D
      ''}";
      Restart = "on-failure";
    };
  };
}
