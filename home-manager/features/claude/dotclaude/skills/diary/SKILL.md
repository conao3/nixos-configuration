---
name: diary
description: Claude Codeでの作業経験を日記として記録し、過去の経験を活用するスキル。「日記 / diary」と言ったときにトリガーされる。作業ログ、解決した問題、学んだこと(TIL)を記録する。
---

# 日記スキル

## ワークフロー

### 1. 過去の日記を確認
作業開始前に関連する情報を取得する。

```bash
grep -r "キーワード" ~/Documents/logseq-src/journals
```

### 2. 日記ファイルを作成または追記
ファイルパス: `~/Documents/logseq-src/journals/YYYY_MM_DD.md`

Logseq形式で記述する。テンプレートは [references/template.md](references/template.md) を参照。

### 3. 記録する内容
- **作業ログ**: 何をしたか、どう解決したか
- **学んだこと (TIL)**: 技術的な知見、発見
- **メモ**: 次回への引き継ぎ事項
