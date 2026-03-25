# mo

k1LoW/mo — Markdown ファイルをブラウザで表示するビューア。ライブリロード対応。

## Quickstart

```sh
mo README.md
```

## 概要

- Markdown ファイルをブラウザでレンダリングして表示する
- GitHub-flavored Markdown、Mermaid、シンタックスハイライト（Shiki）に対応
- YAML frontmatter（折りたたみ表示）、MDX、Raw HTML にも対応
- ファイル保存時に自動リロード
- バックグラウンドで動作し、コマンド実行後すぐにシェルに戻る
- 単一ポートにつき 1 インスタンスで動作し、後から開いたファイルは既存サーバーに追加される
- セッションは自動保存され、サーバー再起動後も復元される

## 基本的な使い方

```sh
mo README.md                          # 単一ファイルを開く
mo README.md CHANGELOG.md docs/*.md   # 複数ファイルを開く
```

2 回目以降の `mo` 呼び出しは、既に起動中のサーバーにファイルを追加する。

## オプション

| オプション | 説明 |
|------------|------|
| `--target, -t <name>` | タブグループ名を指定（デフォルト: `default`） |
| `--port, -p <port>` | サーバーポートを指定（デフォルト: `6275`） |
| `--watch, -w <glob>` | glob パターンにマッチするファイルを監視・追加 |
| `--unwatch <glob>` | 登録済みの glob パターンを解除 |
| `--open` | 既存グループへの追加時もブラウザを開く |
| `--no-open` | ブラウザの自動起動を抑制 |
| `--bind, -b <addr>` | バインドアドレス（デフォルト: `localhost`） |
| `--foreground` | フォアグラウンドで起動（デフォルトはバックグラウンド） |
| `--json` | JSON 形式で出力 |

## サーバー管理

| コマンド | 説明 |
|----------|------|
| `mo --status` | 起動中のサーバー一覧を表示 |
| `mo --shutdown` | デフォルトポートのサーバーを停止 |
| `mo --shutdown -p 6276` | 指定ポートのサーバーを停止 |
| `mo --restart` | セッションを保持してサーバーを再起動 |
| `mo --clear` | 指定ポートのセッションをクリア |

## タブグループ

ファイルをグループに分類して管理できる。グループごとに URL パスが割り当てられる。

```sh
mo spec.md --target design      # http://localhost:6275/design
mo api.md --target design       # "design" グループに追加
mo notes.md --target notes      # http://localhost:6275/notes
```

## セッション復元

セッションは自動保存される。サーバー停止後に `mo` を再実行すると前回のセッションが復元される。

```sh
mo README.md CHANGELOG.md    # 2 ファイルで開始
mo --shutdown                # サーバー停止
mo                           # README.md と CHANGELOG.md が復元される
mo TODO.md                   # 前回のセッション + TODO.md
```

`mo --clear` でセッションを削除できる。

## ファイル監視

glob パターンを指定してディレクトリ内のファイルを自動検出・追加する。ファイル引数との併用は不可。

```sh
mo --watch '**/*.md'                        # 再帰的に全 .md を監視
mo --watch 'docs/**/*.md' --target docs     # docs/ 配下を "docs" グループで監視
mo --watch '*.md' --watch 'docs/**/*.md'    # 複数パターン
mo --unwatch '**/*.md'                      # 監視を解除
```

## 別ポートで独立セッション

ポートを変えると完全に別のセッションとして動作する。

```sh
mo README.md                # デフォルト (port 6275)
mo draft.md --port 6276     # 別セッション (port 6276)
```

## 参考

- https://github.com/k1LoW/mo
