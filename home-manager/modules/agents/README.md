# programs.agents (設計メモ)

コーディングエージェント (Claude Code / Codex / pi / cursor-agent) を、1 台のマシンで複数の設定ディレクトリ (インスタンス) に分けて動かすための home-manager モジュール。nixos-configuration の外へ flake として切り出す前提で、`config` / `lib` / `pkgs` と home-manager の `lib.hm.dag` だけに依存する。利用例は `home-manager/features/claude/`。

## 位置づけ

home-manager 本体の `programs.claude-code` / `programs.codex` / `programs.mcp` は、1 つの設定ディレクトリへ store の symlink を置く。このモジュールは次の 3 点を受け持つ。

- 1 つのプログラムに対する複数のインスタンス (`claude.conao3`、`claude.agent001` …) と、それぞれのラッパー。
- インスタンス間の共有ディレクトリ (履歴・プロジェクト・設定を 1 か所に集める)。
- エージェント自身が書き戻す設定ファイルへの、activation でのマージ。

## 概念の対応表

| 概念 | options | features/claude での書き方 | 生成物 |
|---|---|---|---|
| インスタンス | `instances.<name>` (`type` は名前の最初の `.` より前) | `default.nix` に 15 個を列挙 | `<name>` のラッパー、`baseDir/.<name>` |
| type ごとの bin と env | `types.<t>.package` / `executable` / `envVar` | `default.nix` の `types` | makeWrapper の `--run 'export <envVar>="$HOME/<dir>"'` |
| 既定の設定ディレクトリ | `types.<t>.homeDir` | `.claude` / `.codex` | `scope = "config"` のファイルの書き先 |
| type の共有ディレクトリ | `types.<t>.share.*`、`instances.<name>.share` | claude / codex で有効、`*.worker` は `share = false` | activation `agentsShare` (reconcile) |
| 全エージェント共通のディレクトリ | `common.*` | `.agents/share` に `MEMORY.md` と 3 ディレクトリ | activation `agentsCommon` |
| 指示ファイル | `instructions`、`types.<t>.instructionsFile`、`instances.<name>.instructions` | `AGENTS.md`、worker は `AGENTS-worker.md` | `home.file` の symlink |
| MCP の配布 | `mcpServers.<name>`、`types.<t>.mcp` | `mcp.nix` に 6 個 | 各形式 (claude / codex / cursor) へ変換して `files` へ注入 |
| 秘密のファイル参照 | `mcpServers.<name>.bearerTokenFile` / `bearerTokenEnvVar` | flovia はキーファイル、devin は環境変数 | claude は `headersHelper`、codex は `bearer_token_env_var` |
| settings の構造化パッチ | `types.<t>.files.<file>.settings` と `agentsLib.force` / `delete` | claude の `settings.json`、codex の `config.toml` | ops JSON (store) + `agents-merge` |
| from→to 移行 | `agentsLib.migrate { from; to; }` | `DISABLE_TELEMETRY` を `"1"` から `""` へ | 不一致は `warningsFile` へ警告 |
| マージ戦略 | `files.<file>.strategy` (`merge` / `overwrite` / `link`)、`onConflict` | `settings.json` / `.claude.json` / `config.toml` は merge、`mcp.json` と fugu は overwrite | activation `agentsFiles` |
| ラッパーの追加処理 | `types.<t>.executable` に任意のスクリプト、`instances.<name>.wrapper.makeWrapperArgs`、`extraWrappers` | codex の `--no-daemon` スクリプト、`codex.sakana.agent001`、`cursor.agent001` (GUI) | makeWrapper |
| 別名 | `aliases` | `cursor` / `cursor-agent` / `pi` | `exec <target> "$@"` のスクリプト |
| 常駐サービス | `mcpServers.<name>.service` | drawio (`http://127.0.0.1:3733/mcp`) | systemd user service `<name>-mcp` (Linux のみ) |
| シェルのシム | `zshFunctions.<name>` | `codex` を agmsg の shim 経由にする (`agmsg.nix`) | zsh の関数 (`initContent` の末尾) |

モジュールの外に残すもの: agmsg の skill 配置 (`agmsg.nix` の `home.activation.agmsgSkill`、`agentsDirs` の後)、`~/.claude` の skills、Claude Desktop の設定、`programs.git.ignores`、`sox`。

## ファイルの書き先

`types.<t>.files.<file>` の `<file>` は書き先ディレクトリ内の名前。

- `scope = "config"`: `homeDir` と共有ディレクトリ (`share.enable` のとき)。共有ディレクトリ内のファイルは各インスタンスへ symlink される (`share.forceLinks` へ自動で入る)。
- `scope = "instances"`: その type の全インスタンスのディレクトリ (共有に入らないインスタンスを含む)。
- `extraTargets`: home 相対の追加の書き先 (`~/.claude.json` など)。

`settings` に関数を渡すと `{ dir }` (書き先ディレクトリの絶対パス。`home.homeDirectory` から作る) を受け取る。fugu の `model_catalog_json` がこれを使う。

`types.<t>.mcp.files` に挙げたファイルには、`mcp.key` の位置へ変換済みの MCP サーバーが `force` で入る。

## マージの意味論

`settings` の attrset は葉ごとの操作列にして store の JSON に書き、`agents-merge` が jq (`merge.jq`) で既存ファイルへ当てる。JSON は `builtins.toJSON` で作り、store のファイルとして jq に渡す。

| 葉 | 操作 |
|---|---|
| 値 (`onConflict = "warn"`) | 未設定なら書く。同じ値なら何もしない。別の値なら残して警告する |
| 値 (`onConflict = "overwrite"`) | 常に書く |
| `agentsLib.force v` | その位置の部分木を `v` で置き換える |
| `agentsLib.delete` | キーを消す |
| `agentsLib.migrate { from; to; }` | `from` なら `to` に書き換える。`to` なら何もしない。それ以外は残して警告する |

attrset は再帰し、list と scalar は葉として扱う。対象が無いか空のときは `{}` から始める。対象が symlink のときはリンク先の内容から始め、結果を実ファイルとして置く (リンク先は書き換えない)。書き込みは同じディレクトリに `mktemp` で作った新しいファイルを `mv` で置き換える。TOML は yq で JSON にしてから当て、remarshal で TOML に戻す。JSON / TOML として読めないファイルは activation をエラーで止める。

警告は `warningsFile` に `WARN: <type> settings: <file>: .<path>: expected <from> or <to>, got <current>, skipping` の形で書く。ファイルは毎回の activation で作り直す。

`overwrite` は store に生成したファイル (`pkgs.formats`) を `install -m 0644` で置き直す。`link` は `home.file` で symlink にする (エージェントが書き戻さないファイル向け)。

## 共有ディレクトリの reconcile

`share.enable` の type ごとに、共有に入るインスタンスのディレクトリ (名前順) を走査する。

- `share.exclude` の名前はインスタンスに残す。共有ディレクトリを指す symlink になっていれば、リンク先の内容を写した実ファイルに戻す (リンク先が無ければ消す)。
- symlink は共有側を指すように張り直す。
- ディレクトリは共有側へ移す。共有側に既にあれば上書きせずに中身を足す。
- ファイルは `<共有ディレクトリ>.backup-<日時>/` へ控えてから共有側へ寄せる。
  - `share.history.file` は両方を結合し、重複を除いて `share.history.sortKey` で並べる。
  - `share.keepFirst` に当たるものは先に共有側へ届いたものを残す。
  - `share.discard` と指示ファイルは捨てる。
  - それ以外は新しい方を残す。
- 最後に `share.forceLinks` と、共有側にあってインスタンスに無いものを symlink する。

## activation の順序

1. `agentsDirs`: `baseDir`、`common.dir`、共有ディレクトリ、全インスタンスのディレクトリを作る。
2. `agentsCommon`: `common.ensureFiles` と `common.directories`。
3. `agentsShare`: reconcile。
4. `agentsFiles`: `merge` と `overwrite` のファイル。reconcile の後に走るので、インスタンスで書き換えられた共有ファイルを取り込んでから設定を当てる。

## options

`programs.agents` の下:

- `enable`
- `baseDir` (`.agents`)
- `instructions`
- `common.dir` (`<baseDir>/share`) / `common.instructionsFile` (`AGENTS.md`) / `common.directories` / `common.ensureFiles`
- `warningsFile` (`<baseDir>/settings-warnings.log`)
- `types.<t>`
  - `package` / `executable` (`lib.getExe package`) / `envVar` / `homeDir` / `instructionsFile` (`AGENTS.md`)
  - `share.enable` / `share.dir` (`<baseDir>/.<t>`) / `share.exclude` / `share.forceLinks` / `share.discard` / `share.history.file` (`history.jsonl`) / `share.history.sortKey` (`.timestamp`) / `share.keepFirst` (`*.sqlite*`)
  - `mcp.format` (`claude` / `codex` / `cursor`) / `mcp.key` / `mcp.files`
  - `files.<file>.scope` / `extraTargets` / `format` / `strategy` / `source` / `settings` / `onConflict`
- `instances.<name>`
  - `type` / `dir` (`<baseDir>/.<name>`) / `share` / `instructions`
  - `wrapper.enable` / `wrapper.makeWrapperArgs`
  - `extraWrappers.<exe>.executable` / `extraWrappers.<exe>.makeWrapperArgs`
- `aliases.<exe>`
- `mcpServers.<name>`
  - `url` / `command` / `args` / `env` / `headers`
  - `bearerTokenEnvVar` / `bearerTokenFile`
  - `enableFor` (`mcp` を持つ全 type)
  - `service.description` / `service.execStart`
- `zshFunctions.<name>`

module 引数 `agentsLib` が `force` / `delete` / `migrate` を提供する。

## 評価時の検査

- `instances.<name>.type` が `types` に無い。
- 共有に入るインスタンスに `instructions` を設定した (共有ディレクトリの指示ファイルは `programs.agents.instructions`)。
- `mcpServers.<name>` に `url` と `command` の両方がある、またはどちらも無い。
- `enableFor` の type に `mcp` が無い。
- 変換先の形式で表せない項目 (`bearerTokenFile` を codex / cursor へ配る等) は評価エラーになる。`enableFor` から外す。
- `source` を `merge` で使った。

## 制約

- `service` は Linux の systemd user service として作る。
- activation の書き込みは home-manager の dry run でも実行される (`run` / `DRY_RUN_CMD` を経由していない)。
- `zshFunctions` は zsh だけに出す。
- reconcile と merge の対象は、各ディレクトリの直下の名前。

## flake として切り出す

このディレクトリをそのままリポジトリの root にする。`flake.nix` は `homeManagerModules.default` を出す。利用側は `imports = [ inputs.<name>.homeManagerModules.default ];` で読み込み、`features/claude` の `imports` の相対パスを置き換える。
