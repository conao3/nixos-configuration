# gh

GitHub CLI。リポジトリ、issue、PR などを CLI から操作する。

## リポジトリ

| コマンド | 説明 |
|----------|------|
| `gh repo create <name> --public` | public リポジトリを作成 |
| `gh repo create <name> --private` | private リポジトリを作成 |
| `gh repo create <name> --private --clone` | private リポジトリを作成してクローン |
| `gh repo create <name> --private -d "説明"` | 説明付きで作成 |
| `gh repo create <org>/<name> --private` | organization に作成 |
| `gh repo clone <user>/<project>` | リポジトリをクローン |
| `gh repo view` | リポジトリ情報を表示 |
| `gh repo view --web` | ブラウザで開く |
| `gh repo edit --visibility public --accept-visibility-change-consequences` | private を public に変更 |
| `gh repo edit --visibility private --accept-visibility-change-consequences` | public を private に変更 |

ghq と組み合わせる場合:

```sh
gh repo create conao3/my-repo --private
ghq get conao3/my-repo
```

## Pull Request

| コマンド | 説明 |
|----------|------|
| `gh pr create` | PR を対話的に作成 |
| `gh pr create -t "タイトル" -b "本文"` | タイトルと本文を指定して作成 |
| `gh pr create -d` | draft PR を作成 |
| `gh pr create -B develop` | ベースブランチを指定 |
| `gh pr list` | PR 一覧 |
| `gh pr view <number>` | PR を表示 |
| `gh pr view <number> --web` | PR をブラウザで開く |
| `gh pr checkout <number>` | PR のブランチをチェックアウト |
| `gh pr merge <number>` | PR をマージ |

## Issue

| コマンド | 説明 |
|----------|------|
| `gh issue create` | issue を対話的に作成 |
| `gh issue create -t "タイトル" -b "本文"` | タイトルと本文を指定して作成 |
| `gh issue create -l bug` | ラベル付きで作成 |
| `gh issue list` | issue 一覧 |
| `gh issue view <number>` | issue を表示 |
| `gh issue view <number> --web` | issue をブラウザで開く |
| `gh issue close <number>` | issue を閉じる |

## ブラウザで開く

| コマンド | 説明 |
|----------|------|
| `gh browse` | リポジトリのホームを開く |
| `gh browse <number>` | issue / PR を開く |
| `gh browse <path>` | ファイルを開く |
| `gh browse --settings` | リポジトリ設定を開く |

## API

```sh
gh api repos/<owner>/<repo>/pulls/<number>/comments
```
