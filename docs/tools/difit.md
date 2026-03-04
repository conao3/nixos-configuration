# difit

ローカルで Git の差分を GitHub の "Files changed" 風に表示する CLI ツール。
AI レビューコメントのプロンプト生成機能付き。

## 起動

インストール不要で実行できる。

```sh
pnpm dlx difit@latest
```

## 基本コマンド

| コマンド | 説明 |
|----------|------|
| `difit` | HEAD（最新コミット）を表示 |
| `difit <hash>` | 指定コミットを表示 |
| `difit <branch>` | ブランチの最新コミットを表示 |
| `difit .` | 未コミット変更（staged + unstaged）を表示 |
| `difit staged` | ステージング済みの変更のみ |
| `difit working` | 未ステージの変更のみ |

## 比較

| コマンド | 説明 |
|----------|------|
| `difit @ main` | HEAD と main を比較（`@` は HEAD のエイリアス） |
| `difit feature main` | 2 つのブランチを比較 |
| `difit . origin/main` | ワーキングツリーとリモートを比較 |

## PR レビュー

```sh
difit --pr https://github.com/owner/repo/pull/123
```

## stdin 入力

```sh
diff -u file1.txt file2.txt | difit
cat changes.patch | difit
git diff --cached | difit -
```

## オプション

| オプション | デフォルト | 説明 |
|------------|------------|------|
| `--port` | 4966 | サーバーポート（使用中なら自動インクリメント） |
| `--host` | 127.0.0.1 | バインドアドレス（外部公開は `0.0.0.0`） |
| `--no-open` | false | ブラウザを自動起動しない |
| `--mode` | split | 表示形式（`split` or `unified`） |
| `--tui` | false | ブラウザの代わりに TUI で表示 |
| `--clean` | false | 起動時にコメントと既読状態をリセット |
| `--include-untracked` | false | `.` や `working` で未追跡ファイルも含める |
| `--keep-alive` | false | ブラウザ切断後もサーバーを維持 |
