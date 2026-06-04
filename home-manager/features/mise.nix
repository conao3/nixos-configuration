{ ... }:
{
  # mise: プロジェクト単位のツールバージョン管理 (sdkman/volta/corepack の置き換え)。
  # 各リポジトリの mise.toml / .mise.toml を読んで java/node/pnpm 等を切り替える。
  programs.mise = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
}
