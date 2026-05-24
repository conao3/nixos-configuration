# AGENTS.md

このファイルはすべてのエージェントが共有する世界のルールです。更新禁止。

## ディレクトリ定義

以降で使用する変数：

- `{agent_home}` — 当該エージェントのホームディレクトリ
  - Claude: `$CLAUDE_CONFIG_DIR`
  - Codex: `$CODEX_HOME`
  - Cursor（cursor-agent プロファイル）: `$CURSOR_HOME`
- `{agent_global_home}` — エージェント間で共有するディレクトリ。常に **`$HOME/.agents/share`** とする。`{agent_home}` とは別物。
  - 実体は `~/ghq/github.com/conao3/agents-share/src/` の git レポジトリ。`MEMORY.md` / `MEMORY_SUGGEST/` / `notes/` / `projects/` / `specs/` / `auto-memory/` は symlink でこの repo を指す。`{agent_global_home}` 配下を編集した内容は agents-share でコミットする (conao3 配下なので AGENTS.md の能動的 commit ルールが適用される)。
  - 例外: `AGENTS.md` (このファイル) のみ home-manager が nix store からの read-only symlink として配置する。更新は `~/ghq/github.com/conao3/nixos-configuration/home-manager/features/claude/AGENTS.md` を編集して `make switch` で反映する。
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

`Read` / `Edit` / `Write` / `Bash` などで `~/ghq/github.com/<owner>/<repo>/` の repo 境界をまたぐ瞬間に、**そのファイル操作 (またはコマンド実行) の前に** 対象レポジトリの `projects/{project_dir_canonical}.md` を読む。許可を求めず実行する。

判定:

- trigger は「自分が出そうとしている tool 呼び出しの path / cwd が現在の作業 repo と異なる owner/repo を指していること」。物理判定であり、「主作業の延長」「設定ファイルなので付随作業」「軽い編集だけ」のような自己解釈で省略しない。
- 対象レポジトリが切り替わるたびに、その都度 1 回ずつ。同セッション中に同じ repo へ戻ってきたら再読は不要。
- ファイルが無い場合のフォールバックは「毎セッション開始時」と同じ。
- 該当ファイルが `notes/` への参照を持つ場合は合わせて読む。

これを踏まなかったときに起きる典型損害: 別 repo の `make` / `nix rebuild` / `pnpm db:reset` 等の操作を「破壊的かわからないからユーザー判断」と外に出してしまう (projects メモを読めばエージェント実行可と明記されていることが多い)。逆に projects メモを読まずに勝手に破壊的操作を流す方向の事故も同じ仕組みで起きうる。

## `.claude-dev/` の配置

作業用の一時ファイル (PR 下書き、生成スクリプト、調査メモなど) は対象レポジトリの `.claude-dev/` に置く。

`git worktree` で複数の作業ツリーを持つレポジトリでは、メイン worktree (共有 `.git` を持つディレクトリ。`git rev-parse --path-format=absolute --git-common-dir` の親) に集約する。feature worktree 側に `.claude-dev/` を作らない。

## `ghq/github.com/conao3/` 配下のコミット運用

ユーザー本人のプロジェクト（`~/ghq/github.com/conao3/` 配下）に限り、作業の論理単位ごとに能動的に commit してよい。ユーザーからの明示指示は不要。

- それ以外のレポジトリ（他者・組織所有）はユーザーが明示的に commit と指示することが必要。指示は当該作業単位（一連の commit batch）に対する許可と解釈する。別の論理タスク（別 PR、独立した作業単位）に移ったら、たとえ同セッション内でも再度の明示指示を取り直す。
- commit 直前に `git diff --cached` で staged 内容を必ず目視する。
- commit メッセージは当該レポジトリの慣習に合わせる。`git log --oneline` で過去 commit の実例（言語、prefix の形式、scope の取り方）を確認してから書く。慣習例: lowercase 英語 + `feat:` / `fix:` / `<package>:` / 日本語 + `feat(scope):` など、レポごとに異なる。
- `push` は共有状態を変えるため、引き続きユーザーの明示指示が必要。

## 長期記憶への貢献

ユーザーが「記憶の提案」と指示したとき、次の各ファイルに対する更新案を `MEMORY_SUGGEST/{project_dir_canonical}_{YYYYMMDD}_{%03d}.md` にまとめる（`%03d` は未使用の連番）。

- `{agent_global_home}/MEMORY.md`
- `projects/{project_dir_canonical}.md`
- `notes/{foo}.md`（トピックごとに `{foo}` を定める）

ただし、プロジェクト固有メモ (`projects/{project_dir_canonical}.md`) については、ユーザーから別途禁止されていない限り、直接編集してよい。

- 長期記憶として書き出すファイル (`projects/{project_dir_canonical}.md`、`notes/{foo}.md`、`MEMORY_SUGGEST/` 配下) は日本語で記述する。
- 直接編集したプロジェクト固有メモの内容は、記憶の提案ファイルには重複して書かない。
- 提案として書く内容が無い場合は、`MEMORY_SUGGEST/` にファイルを作成しなくてよい。
- 複数プロジェクトの作業をした場合は、対象プロジェクトごとに直接編集または記憶の提案を行う。
- ユーザーから受けた指摘は、以後のアウトプット品質を改善する重要な知識として扱い、プロジェクト固有メモや notes へ積極的に反映する。
