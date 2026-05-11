# AGENTS.md

このファイルはすべてのエージェントが共有する世界のルールです。更新禁止。

## ディレクトリ定義

以降で使用する変数：

- `{agent_home}` — 当該エージェントのホームディレクトリ
  - Claude: `$CLAUDE_CONFIG_DIR`
  - Codex: `$CODEX_HOME`
  - Cursor（cursor-agent プロファイル）: `$CURSOR_HOME`
- `{agent_global_home}` — エージェント間で共有するディレクトリ。常に **`$HOME/.agents/share`** とする。`{agent_home}` とは別物。
- `{project_dir_canonical}` — リポジトリのメイン作業ツリー（共有 `.git` を含むディレクトリの親）を、ホームからの相対パスにしたうえで `/` と `.` を `-` に置換した識別子。

  ```bash
  MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
  echo "$MAIN" | sed "s|^$HOME/||" | tr /. -
  ```

  `git rev-parse --show-toplevel` は `{project_dir_canonical}` の算出に使わない。

## ファイル構造

```
{agent_global_home}/
  AGENTS.md        # 世界のルール（このファイル）。更新禁止
  MEMORY.md        # エージェントチームの共通知識
  MEMORY_SUGGEST/
    {project_dir_canonical}_{YYYYMMDD}_{%03d}.md  # 長期記憶の提案
  projects/
    {project_dir_canonical}.md  # プロジェクト固有の情報
  notes/
    {foo}.md # 再利用可能な情報
  specs/  # 設計文書
    {project_dir_canonical}/
      {%03d}-{bar}.md

{agent_home}/
```

## 毎セッション開始時

以下の順で読み込む。許可を求めず実行する。

1. `{agent_global_home}/MEMORY.md`
2. `projects/{project_dir_canonical}.md`
   - 当該パスにファイルが無い場合、`projects/ghq-github-com-OWNER-REPO.md`（`git remote get-url origin` に対応する名前）を読む。
   - 本ファイルに `notes/` への参照があれば従う。
3. `notes/ghq.md` と `notes/specs.md` を読む。

## 別レポジトリへ作業を広げるとき

セッション中に当初の `{project_dir_canonical}` 以外のレポジトリへ作業範囲が広がるたび、対象レポジトリの `projects/{project_dir_canonical}.md` を読み込んでから作業に入る。許可を求めず実行する。

- 対象レポジトリが切り替わるたびに、その都度 1 回ずつ。
- ファイルが無い場合のフォールバックは「毎セッション開始時」と同じ。
- 該当ファイルが `notes/` への参照を持つ場合は合わせて読む。

## 長期記憶への貢献

ユーザーが「記憶の提案」と指示したとき、次の各ファイルに対する更新案を `MEMORY_SUGGEST/{project_dir_canonical}_{YYYYMMDD}_{%03d}.md` にまとめる（`%03d` は未使用の連番）。

- `{agent_global_home}/MEMORY.md`
- `projects/{project_dir_canonical}.md`
- `notes/{foo}.md`（トピックごとに `{foo}` を定める）
