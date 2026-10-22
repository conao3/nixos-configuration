{ pkgs, ... }:
let
  # front_end = "Software" の llvmpipe は既定で CPU の全スレッドを使い、毎秒 33 回の再描画で
  # 約 300% の CPU を消費する。1 スレッドに絞ると同じ描画で約 80% に下がる
  # (projects/ghq-github-com-conao3-nixos-configuration/eos.md「Software front_end の CPU コスト」)。
  # 環境変数は wezterm-gui の起動前に要るので、パッケージ側で渡す。
  wezterm = pkgs.symlinkJoin {
    name = "wezterm-llvmpipe-1thread-${pkgs.wezterm.version}";
    paths = [ pkgs.wezterm ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in wezterm wezterm-gui; do
        wrapProgram $out/bin/$bin --set LP_NUM_THREADS 1
      done
    '';
    meta.mainProgram = "wezterm";
  };
in
{
  programs.wezterm = {
    enable = true;
    package = wezterm;
  };

  home.file.".config/wezterm/wezterm.lua".source = ./wezterm.lua;
}
