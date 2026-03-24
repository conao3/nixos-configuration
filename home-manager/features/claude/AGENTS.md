# AGENTS.md

このファイルはすべてのエージェントが共有する世界のルールです。更新禁止。

## ディレクトリ定義

以降で使用する変数：

- `{agent_home}` — このエージェントのホームディレクトリ
  - Claude: `$CLAUDE_CONFIG_DIR`
  - Codex: `$CODEX_HOME`
- `{agent_global_home}` — エージェントチーム共通のディレクトリ（`~/.agents/share`）
- `{project_dir_canonical}` - `git rev-parse --show-toplevel | sed "s|^$HOME/||" | tr /. -`

## ファイル構造

```
{agent_global_home}/
  AGENTS.md        # 世界のルール（このファイル）。更新禁止
  MEMORY.md        # エージェントチームの共通知識
  MEMORY_SUGGEST/
    {project_dir_canonical}_{YYYYMMDD}_{%03d}.md  # 長期記憶の提案
  projecs/
    {project_dir_canonical}.md  # プロジェクト固有の情報
  notes/
    {foo}.md # 再利用可能な情報
  specs/  # 設計文書
    {project_dir_canonical}/
      {%03d}-{bar}.md

{agent_home}/
```

## 毎セッション開始時

以下の順番でファイルを読み込むこと。許可を求めず、必ず実行すること。

1. `{agent_global_home}/MEMORY.md`
2. `projecs/{project_dir_canonical}.md`
  - このファイルにnotesへの参照がある場合がある
3. 以下のnotesを読む
  - ghq
  - specs

## 長期記憶への貢献

セッションを越えて今回の知見を残すことはとても有意義なことです。
ユーザーが「記憶の提案」とコメントしたら、あなたが今回調べたり指示された知識などを以って
以下のファイルそれぞれについてどんな内容で更新したら良いかを考え、
`MEMORY_SUGGEST/{project_dir_canonical}_{YYYYMMDD}_{%03d}.md` (%03dは使用していない連番)にファイルを作ってください。
- `{agent_global_home}/MEMORY.md`
- `projects/{project_dir_canonical}.md`
- `notes/{foo}.md`
  fooは変数のため、記録したいトピックごとに記載すること。
