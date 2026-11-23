{ pkgs, ... }:
{
  programs.mpv = {
    enable = true;
    package = pkgs.mpv.override { yt-dlp = pkgs.yt-dlp.override { javascriptSupport = false; }; };
    config = {
      volume-max = 200;
    };
    bindings = {
      n = "af toggle lavfi=[dynaudnorm=f=150:g=15:p=0.9:m=20]";
      N = "af toggle lavfi=[acompressor=threshold=-30dB:ratio=6:attack=5:release=300:makeup=10]";
    };
  };
}
