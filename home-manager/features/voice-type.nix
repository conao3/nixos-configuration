{ config, pkgs, ... }:
{
  # F9 (日本語は Shift+F9) で voice-type (pkgs/voice-type.nix: マイクの音声を whisper.cpp でローカルに文字起こしして打ち込む) を呼ぶ。
  # XFCE のショートカット (xfconf の /commands/custom) は、switch の後に xfsettingsd の登録が外れる
  # (home-manager の書き込みと xfsettingsd の状態がずれる) ので、独立したホットキーデーモンの sxhkd を使う。
  # `@` はキーを離したときに実行する指定で、押しっぱなしの自動リピートで連続起動 (= 録音停止) しないための指定。
  home.packages = [ pkgs.sxhkd ];

  xdg.configFile."sxhkd/sxhkdrc".text = ''
    @F9
      ${config.home.profileDirectory}/bin/voice-type
    @shift + F9
      ${config.home.profileDirectory}/bin/voice-type --ja
  '';

  # XFCE のセッション開始時に起動する。設定の再読み込みは make switch が `pkill -USR1 -x sxhkd` で行う
  xdg.configFile."autostart/sxhkd.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=sxhkd
    Exec=${pkgs.sxhkd}/bin/sxhkd
    X-GNOME-Autostart-enabled=true
  '';
}
