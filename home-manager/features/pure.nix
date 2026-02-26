{ pkgs, ... }:
{
  programs.zsh = {
    plugins = [
      {
        name = "pure";
        src = "${pkgs.pure-prompt}/share/zsh/site-functions";
      }
    ];
    initContent = ''
      autoload -U promptinit; promptinit
      zstyle :prompt:pure:path color cyan
      zstyle :prompt:pure:environment:nix-shell show no
      prompt pure
    '';
  };
}
