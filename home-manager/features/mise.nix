{ config, ... }:
{
  # mise: プロジェクト単位のツールバージョン管理 (sdkman/volta/corepack の置き換え)。
  # 各リポジトリの mise.toml / .mise.toml を読んで java/node/pnpm 等を切り替える。
  programs.mise = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # mise を使わないプロジェクト。配下の mise.toml / .mise.toml を無視する。
  # globalConfig の settings.ignored_config_paths は project config の trust 判定に
  # 反映されないため、環境変数で指定する (~ は展開されないため絶対パス)。
  home.sessionVariables.MISE_IGNORED_CONFIG_PATHS = builtins.concatStringsSep ":" [
    "${config.home.homeDirectory}/ghq/github.com/recerqa/rq-applications"
  ];
}
