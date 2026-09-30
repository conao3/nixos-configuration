{ pkgs, ... }:
let
  # 1Password CLI はデスクトップアプリの承認を「制御端末 (tty) + その開始時刻」単位で覚える。
  # エージェントの Bash は呼び出しごとに tty の無いプロセスで動くため、op のたびに Authorize が出る。
  # op-agent は常駐 tmux session `op-auth` の pane (tty が固定) で op を実行し、
  # 承認を 1 回で済ませる (最後の使用から 10 分、最長 12 時間有効)。
  opAgent = pkgs.writeShellApplication {
    name = "op-agent";
    runtimeInputs = [
      pkgs.tmux
      pkgs.coreutils
    ];
    text = ''
      session=op-auth
      timeout=''${OP_AGENT_TIMEOUT:-180}

      tmux has-session -t "$session" 2>/dev/null || tmux new-session -d -s "$session"

      dir=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/op-agent.XXXXXX")
      trap 'rm -rf "$dir"' EXIT

      # 標準入力はパイプかファイルのときだけ渡す。エージェントの Bash は端末でもパイプでもない
      # 開きっぱなしの stdin を持つので、それを cat すると EOF が来ずに固まる
      if [ -p /dev/stdin ] || [ -f /dev/stdin ]; then
        cat >"$dir/in"
      else
        : >"$dir/in"
      fi

      # 引数 (秘密を含みうる) は pane のシェル履歴に残さず、0700 の一時ディレクトリのスクリプトに置く
      {
        printf 'op'
        printf ' %q' "$@"
        printf ' <%q >%q 2>%q\n' "$dir/in" "$dir/out" "$dir/err"
        printf 'echo $? >%q.tmp && mv %q.tmp %q\n' "$dir/rc" "$dir/rc" "$dir/rc"
      } >"$dir/run.sh"

      tmux send-keys -t "$session" -l " bash $dir/run.sh"
      tmux send-keys -t "$session" Enter

      waited=0
      while [ ! -f "$dir/rc" ]; do
        if [ "$waited" -ge $((timeout * 10)) ]; then
          echo "op-agent: timed out after ''${timeout}s (Authorize ダイアログを確認)" >&2
          exit 124
        fi
        sleep 0.1
        waited=$((waited + 1))
      done

      cat "$dir/out"
      cat "$dir/err" >&2
      exit "$(cat "$dir/rc")"
    '';
  };
in
{
  home.packages = [ opAgent ];

  xdg.configFile."autostart/1password.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=1Password
    Exec=1password --silent
    X-GNOME-Autostart-enabled=true
  '';
}
