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

## fzf との連携

```sh
cd $(ghq list -p | fzf)
```
