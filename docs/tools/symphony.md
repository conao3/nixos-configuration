# symphony

openai/symphony — Linearのissueを監視し、コーディングエージェントを自動起動する長期実行サービス。

## Quickstart

```sh
cd ~/ghq/github.com/your-org/your-repo
symphony ./WORKFLOW.md
```

`pkgs/symphony.nix` の `symphony-skip-guardrails-ack.patch` で起動 ack flag を省略してあるため、追加フラグなしで動く。

## 概要

- Linear の issue を監視し、割り当てられた issue に対して自動的にコーディングエージェントを起動する。
- issue ごとに隔離されたワークスペースを作成し、エージェントセッションを実行する。
- Elixir/OTP製（BEAM VM上で動作）。

## 前提条件

| 項目 | 説明 |
|------|------|
| `LINEAR_API_KEY` | Linear の Personal API Key。orchestrator が Linear ポーリングで読む。helios では sops template `helios-env` 経由で `.envrc` から自動継承される |
| `WORKFLOW.md` | エージェントのプロンプトやランタイム設定を定義するファイル (リポジトリ直下) |

## 使い方

```sh
symphony [--logs-root <path>] [--port <port>] [path-to-WORKFLOW.md]
```

| オプション | 説明 |
|------------|------|
| `path-to-WORKFLOW.md` | ワークフロー定義ファイル（デフォルト: `./WORKFLOW.md`） |
| `--logs-root <path>` | ログの保存先ディレクトリ |
| `--port <port>` | ステータスダッシュボード（Phoenix LiveView）のポート |

## Initialize new project

claude-app-server を backend として使う新規 sandbox の組み立ては `notes/playbook/init-symphony-claude.md` (agents-share) に集約してある。`WORKFLOW.md` の front matter / agent prompt / `.envrc` / `flake.nix` / Linear project 作成 / `gh repo clone` ベースの `hooks.after_create` / `ANTHROPIC_MODEL` 渡し方をひととおりカバーしている。

ここでは Symphony 共通で必要な Linear 側の準備のみ記す。

### Linear のカスタムステータスを追加する

symphony のワークフローは以下の非標準ステータスに依存する。Linear の Team Settings → Workflow で追加すること。

| ステータス名 | タイプ |
|-------------|--------|
| `Human Review` | started |
| `Merging` | started |
| `Rework` | started |

### Linear プロジェクトを作成する

Linear で新しいプロジェクトを作成し、slug を取得する。

slug は作成後の URL から確認できる:

```
https://linear.app/<team>/project/<slug>
```

取得した slug を `WORKFLOW.md` の `linear.project_slug` に設定する。`linear:` block が front matter に存在することで Symphony は tracker backend を `linear` と auto-detect する (`tracker.kind` フィールドは読まれない)。

## 参考

- https://github.com/openai/symphony
- `notes/playbook/init-symphony-claude.md` — claude-app-server backend の sandbox 立ち上げ playbook
