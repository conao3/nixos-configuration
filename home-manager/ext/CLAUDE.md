# claudeについて
- 返答は日本語で行う。

# 作業について
- プロジェクトでの作業を開始するときに一番最初にすることは、READMEを読むこと。
- 次にMakefileを確認します。Makefileに有用なjobが定義されていることが多いです。
- 次にpackage.jsonなど言語ごとの設定ファイルを読みます。これらも有用なスクリプトが定義されていることがあります。
- 必要な一時ファイルを作成するときは .claude-dev ディレクトリを作成して利用してください。
  - 一時ファイルだけではなく、必要なレポジトリをcloneしてくることも許可します。

# コーディングスタイルについて
- コメントを追加することは禁止です。
- 既存のコメントは編集のみ許可します。対応するコード全体を削除したときを除き、削除することは禁止です。
- 変数は基本的には使わないでください。しかし明らかに冗長になるときは可能です。

## Makefileについて
- プロジェクトで使用するコマンドはMakefileで定義します。言語独自の設定ファイルでスクリプトを定義することは禁止です。
- .PHONYターゲットは各ターゲットごとに記述すること。

## Clojureについて
- deps.ednを使います。
- できるだけスレッディングマクロを使用すること。
- テストのために `defn-` を `defn` に変更することは禁止です。この場合、var参照で直接呼び出すことができます。

## ClojureScriptについて
- figwheelはこれを参考にしてください。 https://github.com/conao3/sample-clojure-make-kanban/tree/master/sections/section02
- shadow-cljsはこれを参考にしてください。 https://github.com/conao3/sample-clojure-make-kanban/tree/master/sections/section99

## TypeScriptについて
- `as const` を利用して型情報を狭くするようにすること。

## Pythonについて
- uvを使います。

## シェルスクリプトについて
- bashを使います。
- shebangは `#!/usr/bin/env bash` を記述します。
- 冒頭に `set -euxo pipefail -o posix` を記述してからプログラムを記述します。
- 基本的にコマンドが失敗したら `set -e` の効果により、その場で終了するようにします。

## Nixについて
- flakeを使います。
- flake-partsを使います。
- treefmtを使います。
  - 設定は必要最小限にし、基本的に `programs.*.enable = true` を設定するだけとします。
  - config.treefmt.build.wrapperを追加することは禁止です。
- shellHookでメッセージを出力するような設定を追加することは禁止です。
- devShellにgitを追加することは禁止です。
- サポートするArchは "x86_64-linux" "aarch64-darwin" です。
- 使用しない変数を定義することは禁止です。
- バージョンを指定し、overlayとして上書きします。つまり以下の形となります。
  ```nix
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    overlay = final: prev: let
      jdk = prev.jdk21;
      nodejs = prev.nodejs_22;
      clojure = prev.clojure.override {inherit jdk;};
      pnpm = prev.pnpm_10.override {inherit nodejs;};
    in {
      inherit jdk nodejs clojure pnpm;
    };
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [overlay];
    };
  in {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        jdk
        clojure
        nodejs
        pnpm
      ];
    };
  };
  ```
- nixpkgsでの名前
  - graalvm: graalvmPackages.graalvm-ce

## NixOSについて
- NixOSの環境でコマンドが動作しない場合は `steam-run` を前置することで起動することができます。
- Makefileに `steam-run` を記述することは禁止です。 `steam-run make foo` と起動することで動作させることができます。

# ファイルについて
- ファイル末尾は改行で終わること。
- 行の終わりに空白を入れるのは禁止です。

# gitについて
- コミットはユーザーが「commit」と指示したときのみ行い、勝手にコミットすることは禁止です。
  - Claude Code Webについてはユーザーの許可なしでコミットすることを許可します。
- コミット前に `git diff --cached` を実行して、変更内容を確認すること。
- コミットメッセージに Co-authored-by のセクションを追加することは禁止です。
- コミットメッセージは小文字始まりの英語で書くこと。
- 書いたコミットメッセージはユーザーに報告すること。

## .gitignoreについて
- 必要最小限のエントリのみ追加します。特にOSやユーザーの開発環境に特有のエントリを追加することは禁止です。
- できるだけ `/` を前置して、必要最低限のignore指定をすること。
- 以下に関連するエントリを追加することは禁止です。
  - .claude
  - .direnv
