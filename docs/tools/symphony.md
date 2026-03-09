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

## WORKFLOW.md

対象リポジトリのルートに `WORKFLOW.md` を作成する。symphonyリポジトリの `elixir/WORKFLOW.md` を参考にカスタマイズする。

```sh
ghq get openai/symphony
cat $(ghq root)/github.com/openai/symphony/elixir/WORKFLOW.md
```

## 参考

- https://github.com/openai/symphony
