# symphony

openai/symphony — Linearのissueを監視し、コーディングエージェントを自動起動する長期実行サービス。

## Quickstart

```sh
cd ~/ghq/github.com/your-org/your-repo
export LINEAR_API_KEY=your-key
symphony ./WORKFLOW.md --i-understand-that-this-will-be-running-without-the-usual-guardrails
```

## 概要

- Linearのissueを監視し、割り当てられたissueに対して自動的にコーディングエージェントを起動する
- issueごとに隔離されたワークスペース（git worktree）を作成し、エージェントセッションを実行する
- Elixir/OTP製（BEAM VM上で動作）

## 前提条件

| 項目 | 説明 |
|------|------|
| `LINEAR_API_KEY` | Linear の Personal API Key。環境変数として設定する |
| `WORKFLOW.md` | エージェントのプロンプトやランタイム設定を定義するファイル |

helios では `LINEAR_API_KEY` は sops 経由で自動設定される。

## 使い方

```sh
symphony [--logs-root <path>] [--port <port>] [path-to-WORKFLOW.md]
```

| オプション | 説明 |
|------------|------|
| `path-to-WORKFLOW.md` | ワークフロー定義ファイル（デフォルト: `./WORKFLOW.md`） |
| `--logs-root <path>` | ログの保存先ディレクトリ |
| `--port <port>` | ステータスダッシュボード（Phoenix LiveView）のポート |
| `--i-understand-that-this-will-be-running-without-the-usual-guardrails` | 必須フラグ。プロトタイプソフトウェアであることの確認 |

## Initialize new project

新しいリポジトリで symphony を使い始める手順。

### 1. WORKFLOW.md を作成する

`openai/symphony` の `elixir/WORKFLOW.md` をベースにコピーして編集する。

```sh
cp $(ghq root)/github.com/openai/symphony/elixir/WORKFLOW.md ./WORKFLOW.md
```

以下の箇所をプロジェクトに合わせて変更する。

| 項目 | 変更内容 |
|------|----------|
| `tracker.project_slug` | Linear プロジェクトの slug（後述） |
| `workspace.root` | `~/.symphony-workspaces` |
| `hooks.after_create` | 対象リポジトリをクローン + 言語に応じた依存取得コマンド |
| `hooks.before_remove` | 不要なら削除（Rust など特別なクリーンアップが不要な場合） |

Rust プロジェクトの場合の `hooks` 例:

```yaml
hooks:
  after_create: |
    git clone --depth 1 https://github.com/<owner>/<repo> .
    cargo fetch
```

### 2. Linear のカスタムステータスを追加する

symphony のワークフローは以下の非標準ステータスに依存する。Linear の Team Settings → Workflow で追加すること。

| ステータス名 | タイプ |
|-------------|--------|
| `Human Review` | started |
| `Merging` | started |
| `Rework` | started |

### 3. Linear プロジェクトを作成する

Linear で新しいプロジェクトを作成し、slug を取得する。

slug は作成後の URL から確認できる:

```
https://linear.app/<team>/project/<slug>
```

取得した slug を `WORKFLOW.md` の `tracker.project_slug` に設定する。

### 4. スキルをリポジトリにコピーする

スキルはオプションだが、`land`（PR マージ）や `linear`（Linear 操作）などが WORKFLOW.md のプロンプトから参照される。

```sh
cp -r $(ghq root)/github.com/openai/symphony/.codex ./
```

スキル一覧: `commit`, `push`, `pull`, `land`, `linear`, `debug`

`linear` スキルは symphony が app-server セッション中に注入する `linear_graphql` ツールに依存する。

### 5. symphony を起動する

```sh
cd ~/ghq/github.com/<owner>/<repo>
symphony ./WORKFLOW.md --i-understand-that-this-will-be-running-without-the-usual-guardrails
```

## 参考

- https://github.com/openai/symphony
