# git-wt

`git worktree` をシンプルに扱うための Git サブコマンド。

## シェル統合

自動ディレクトリ切り替えと補完を有効にする。

```sh
# zsh
eval "$(git wt --init zsh)"

# bash
eval "$(git wt --init bash)"

# 補完のみ（自動 cd なし）
eval "$(git wt --init zsh --nocd)"
```

## Quickstart

```sh
git wt feature-x    # feature-x ブランチの worktree を作成して移動
# ... 作業 ...
git wt master        # master の worktree に戻る
git wt -d feature-x  # worktree とブランチを削除
```

## worktree の一覧

| コマンド | 説明 |
|----------|------|
| `git wt` | 全 worktree を一覧表示 |
| `git wt --json` | JSON 形式で出力 |

## worktree の作成・切り替え

| コマンド | 説明 |
|----------|------|
| `git wt <branch>` | ブランチの worktree を作成 or 切り替え |
| `git wt <path>` | パス指定で切り替え |
| `git wt --nocd <branch>` | 自動 cd せずパスだけ表示 |

ブランチが存在しない場合は新規作成される。既に worktree がある場合はそこへ切り替える。

## worktree の削除

| コマンド | 説明 |
|----------|------|
| `git wt -d <branch>` | マージ済みなら削除 |
| `git wt -D <branch>` | 強制削除 |

デフォルトブランチ（main/master）は `--allow-delete-default` なしでは削除できない。

## 設定

`git config` で設定する。コマンドラインフラグ `--<option>=<value>` で一時的に上書き可能。

| オプション | 説明 | デフォルト |
|------------|------|------------|
| `wt.basedir` | worktree の配置先 | `.wt` |
| `wt.copyignored` | .gitignore 対象ファイルをコピー | `false` |
| `wt.copyuntracked` | 未追跡ファイルをコピー | `false` |
| `wt.copymodified` | 変更済みファイルをコピー | `false` |
| `wt.copy` | 常にコピーするパターン | — |
| `wt.nocopy` | コピーから除外するパターン | — |
| `wt.hook` | worktree 作成後に実行するコマンド | — |
| `wt.deletehook` | worktree 削除前に実行するコマンド | — |
| `wt.nocd` | 自動 cd を無効化 | `false` |

### 設定例

```sh
git config --global wt.copyignored true
git config --global wt.hook "npm install"
```

## PR レビューでの活用

```sh
git fetch origin pull/123/head:pr-123
git wt pr-123      # PR 用の worktree を作成
# ... レビュー・テスト ...
git wt -D pr-123   # 後片付け
```
