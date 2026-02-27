# ghq

root: `~/ghq`

リポジトリを `~/ghq/<host>/<user>/<project>` の構造で管理する。

## Quickstart

```sh
ghq get conao3/nixos-configuration
cd $(ghq root)/github.com/conao3/nixos-configuration
```

## リポジトリの取得

| コマンド | 説明 |
|----------|------|
| `ghq get <user>/<project>` | GitHub リポジトリをクローン |
| `ghq get <URL>` | URL を指定してクローン |
| `ghq get -p <user>/<project>` | SSH でクローン |
| `ghq get -u <user>/<project>` | 既存リポジトリを更新 |
| `ghq get --shallow <user>/<project>` | shallow クローン |
| `ghq get -b <branch> <user>/<project>` | ブランチ指定でクローン |

## リポジトリの一覧

| コマンド | 説明 |
|----------|------|
| `ghq list` | 相対パスで一覧表示 |
| `ghq list -p` | フルパスで一覧表示 |
| `ghq list <query>` | 名前でフィルタ |
| `ghq list -e <query>` | 完全一致でフィルタ |

## その他

| コマンド | 説明 |
|----------|------|
| `ghq rm <user>/<project>` | リポジトリを削除 |
| `ghq create <user>/<project>` | 新規リポジトリを作成 |
| `ghq root` | ルートディレクトリを表示 |

## リポジトリのリネーム

ghq にはリネーム専用コマンドはない。リモート (GitHub 等) でリネームした後、以下の手順で対応する。

```sh
ghq rm <old-user>/<old-project>
ghq get <new-user>/<new-project>
```

ローカルで手動移動した場合は `ghq migrate` で ghq 管理下に取り込む。

```sh
ghq migrate /path/to/manually-moved-repo
```

## fzf との連携

```sh
cd $(ghq list -p | fzf)
```
