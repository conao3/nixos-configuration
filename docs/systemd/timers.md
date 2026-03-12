# systemd timers

`cron` の代わりに `systemd timer` を使う。NixOS / Home Manager の設定に直接書けるので、このリポジトリではこちらを使う。

## 使い分け

- `systemd.services.<name>` + `systemd.timers.<name>`: system 全体で動かす
- `systemd.user.services.<name>` + `systemd.user.timers.<name>`: user として動かす

判断基準:
- root 権限や system resource を扱うなら system timer
- `HOME` 配下のファイルや通知、ユーザー用ジョブなら user timer

このリポジトリの実例:
- user timer: `hosts/helios/default.nix`
- system timer: `hosts/helios/default.nix`

## 最小構成

```nix
systemd.user.services.example-job = {
  description = "Example job";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.writeShellScript "example-job" ''
      set -euxo pipefail -o posix
      echo "hello"
    ''}";
  };
};

systemd.user.timers.example-job = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnBootSec = "3min";
    OnUnitActiveSec = "1h";
    Persistent = true;
    RandomizedDelaySec = "5min";
  };
};
```

ポイント:
- timer 名と service 名は揃える
- `Type = "oneshot"` を使うと定期バッチ向き
- `wantedBy = [ "timers.target" ]` を付けると timer が有効化される
- `Persistent = true` を付けると停止中に取りこぼした実行を次回起動時に回収できる
- `RandomizedDelaySec` は複数台で同時実行を避けたいときに便利

## スケジュール指定

よく使う指定:

| 設定 | 意味 |
|------|------|
| `OnBootSec = "3min"` | 起動 3 分後に初回実行 |
| `OnStartupSec = "3min"` | systemd 起動 3 分後に初回実行 |
| `OnUnitActiveSec = "1h"` | 前回実行から 1 時間後に再実行 |
| `OnCalendar = "*-*-* 03:00:00"` | 毎日 03:00 に実行 |
| `OnCalendar = "hourly"` | 毎時実行 |
| `OnCalendar = "Mon *-*-* 09:00:00"` | 毎週月曜 09:00 に実行 |

使い分け:
- 一定間隔で回したいなら `OnBootSec` + `OnUnitActiveSec`
- 壁時計ベースで回したいなら `OnCalendar`

`OnCalendar` の例:

```nix
systemd.timers.example-job = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "daily";
    Persistent = true;
  };
};
```

## このリポジトリでの書き方

system timer の例:

```nix
systemd.services.gitea-mirror = {
  description = "Mirror local git repositories to Gitea";
  serviceConfig = {
    Type = "oneshot";
    User = "conao";
    TimeoutStartSec = "30min";
    ExecStart = "${pkgs.writeShellScript "gitea-mirror" ''
      set -euxo pipefail -o posix
      # ...
    ''}";
  };
};

systemd.timers.gitea-mirror = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnBootSec = "10min";
    OnUnitActiveSec = "6h";
    Persistent = true;
  };
};
```

user timer の例:

```nix
systemd.user.services.memory-alert = {
  description = "Memory usage alert";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.writeShellScript "memory-alert" ''
      set -euxo pipefail -o posix
      # ...
    ''}";
  };
};

systemd.user.timers.memory-alert = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnBootSec = "1min";
    OnUnitActiveSec = "1min";
  };
};
```

## 反映

NixOS 側:

```sh
sudo nixos-rebuild switch --flake .#<host>
```

Home Manager 側:

```sh
home-manager switch --flake .#<user>@<host>
```

Darwin + Home Manager の場合:

```sh
darwin-rebuild switch --flake .#<host>
```

## 確認

system timer:

```sh
systemctl list-timers
systemctl status example-job.timer
systemctl status example-job.service
journalctl -u example-job.service -n 100 --no-pager
```

user timer:

```sh
systemctl --user list-timers
systemctl --user status example-job.timer
systemctl --user status example-job.service
journalctl --user -u example-job.service -n 100 --no-pager
```

手動実行:

```sh
systemctl start example-job.service
systemctl --user start example-job.service
```

## 検索

`systemd timer` 自体にタグ機能はない。検索は unit 名や `Description` ベースで行う。

実行中の timer を探す:

```sh
systemctl list-timers --all | grep codex
systemctl --user list-timers --all | grep codex
systemctl list-units --type=timer | grep heartbeat
systemctl --user list-units --type=timer | grep heartbeat
```

service も含めて探す:

```sh
systemctl list-units | grep codex
systemctl --user list-units | grep codex
```

unit 定義を確認する:

```sh
systemctl cat codex-heartbeat.timer
systemctl --user cat codex-heartbeat.timer
```

このリポジトリの Nix 設定を検索する:

```sh
rg -n 'systemd\\.(user\\.)?(services|timers)\\.' .
rg -n 'codex|heartbeat|timerConfig|OnCalendar|OnUnitActiveSec' .
```

検索しやすくしたい場合は、unit 名に `codex-` のような接頭辞を付ける。

## よくある注意点

- 長時間走るジョブは `TimeoutStartSec` を明示する
- 環境変数が必要なら `serviceConfig.Environment` か script 内で設定する
- PATH に依存せず `${pkgs.xxx}/bin/yyy` で実行ファイルを固定する
- user timer はログインしていないと止まることがある。常駐させたいなら linger も検討する
- `Restart=` は常駐 service 向け。timer で起動する `oneshot` では普通は不要
