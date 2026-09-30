{ inputs, system, ... }:
{
  # システム音声を字幕にする語学学習アプリ (conao3/rust-overhear)。
  home.packages = [ inputs.overhear.packages.${system}.default ];

  # overhear の既定の翻訳エンジン。モデルは ~/.ollama に `ollama pull` で置く。
  services.ollama.enable = true;
}
