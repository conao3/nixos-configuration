{ config, pkgs, ... }:
let
  # 1Password CLI はデスクトップアプリの承認を「制御端末 (tty) + その開始時刻」単位で覚える。
  # エージェントの Bash は呼び出しごとに tty の無いプロセスで動くため、op のたびに Authorize が出る。
  # op-agent は常駐 tmux session `op-auth` の pane (tty が固定) で op を実行し、
  # 承認を 1 回で済ませる。承認は 10 分使わないと切れるので、同じ pane で 4 分おきに
  # op whoami を打ち、最長の 12 時間まで保つ (認可の切れた tty の whoami はダイアログを出さない)。
  opAgent = pkgs.writeShellApplication {
    name = "op-agent";
    runtimeInputs = [
      pkgs.tmux
      pkgs.coreutils
    ];
    text = ''
      session=op-auth
      timeout=''${OP_AGENT_TIMEOUT:-180}

      keepalive=''${XDG_RUNTIME_DIR:-/tmp}/op-agent-keepalive.pid

      tmux has-session -t "$session" 2>/dev/null || tmux new-session -d -s "$session"

      if ! { [ -f "$keepalive" ] && kill -0 "$(cat "$keepalive")" 2>/dev/null; }; then
        tmux send-keys -t "$session" -l " (while sleep 240; do /run/wrappers/bin/op whoami >/dev/null 2>&1; done) & echo \$! >$keepalive"
        tmux send-keys -t "$session" Enter
      fi

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
        printf '/run/wrappers/bin/op'
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
  opUnlock = pkgs.writeShellApplication {
    name = "op-unlock";
    runtimeInputs = [
      pkgs.xdotool
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      export DISPLAY=''${DISPLAY:-:0}
      secret=''${XDG_CONFIG_HOME:-$HOME/.config}/1password-agent/master.pass

      systemctl --user is-active --quiet onepassword || systemctl --user start onepassword

      window() {
        xdotool search --onlyvisible --name "$1" 2>/dev/null | head -n 1
      }

      /run/current-system/sw/bin/1password >/dev/null 2>&1 &
      waited=0
      until [ -n "$(window 'Lock Screen — 1Password|All Items — 1Password')" ]; do
        if [ "$waited" -ge 30 ]; then
          echo "op-unlock: the 1Password window did not appear" >&2
          exit 1
        fi
        sleep 1
        waited=$((waited + 1))
      done

      lock=$(window 'Lock Screen — 1Password')
      if [ -n "$lock" ]; then
        xdotool windowactivate --sync "$lock"
        xdotool mousemove --window "$lock" 470 400 click 1
        sleep 1
        xdotool type --delay 40 --file "$secret"
        xdotool key Return
        waited=0
        until [ -n "$(window 'All Items — 1Password')" ]; do
          if [ "$waited" -ge 30 ]; then
            echo "op-unlock: the lock screen did not open" >&2
            exit 1
          fi
          sleep 1
          waited=$((waited + 1))
        done
      fi
      echo "op-unlock: unlocked"
    '';
  };
in
{
  home.packages = [
    opAgent
    opUnlock
  ];

  systemd.user.services.onepassword = {
    Unit = {
      Description = "1Password desktop app";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=${config.home.homeDirectory}/.Xauthority"
        "PATH=/run/wrappers/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      ExecStart = "/run/current-system/sw/bin/1password --silent";
      KillSignal = "SIGINT";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.configFile."chrome-devtools/profiles/conao3/NativeMessagingHosts/com.1password.1password.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/google-chrome/NativeMessagingHosts/com.1password.1password.json";
}
