# fzf

汎用のファジーファインダー。標準入力の候補を対話的に絞り込み、選択結果を標準出力に返す。

## Quickstart

```sh
# 候補から1つ選ぶ
printf '%s\n' apple banana orange | fzf

# ファイル名を選ぶ
find . -type f | fzf

# 履歴から選ぶ
history | fzf
```

## よく使うオプション

| オプション | 説明 |
|------------|------|
| `--query "text"` | 初期クエリを指定 |
| `--multi` | 複数選択を有効化 |
| `--preview 'cmd {}'` | 右ペインでプレビュー |
| `--height 40%` | 表示高さを指定 |
| `--reverse` | プロンプトを上側に表示 |
| `--prompt 'Select> '` | プロンプト文字列を変更 |

## シェルでの利用パターン

選択結果を変数に入れて使う:

```sh
file=$(find . -type f | fzf)
[ -n "$file" ] && "$EDITOR" "$file"
```

複数選択を受け取る:

```sh
files=$(find . -type f | fzf --multi)
[ -n "$files" ] && printf '%s\n' "$files"
```

## この環境での連携

`ghq` のラッパー関数で `ghq cd` 時に fzf を使っている。

```sh
ghq cd
```

実体は以下の流れ:

```sh
repo=$(ghq list | fzf --query "conao3/")
cd "$(ghq root)/$repo"
```
