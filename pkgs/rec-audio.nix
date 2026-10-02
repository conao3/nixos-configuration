{
  writeShellApplication,
  ffmpeg,
  pulseaudio,
}:
writeShellApplication {
  name = "rec-audio";
  runtimeInputs = [
    ffmpeg
    pulseaudio
  ];
  text = ''
    usage() {
      cat <<'EOF'
    usage: rec-audio [-o DIR] [-s SYSTEM_SOURCE] [-m MIC_SOURCE] [-l]

    システム音声 (既定の出力の monitor) とマイク (既定の入力) を同時に録音する。Ctrl-C で停止。
    DIR/YYYYMMDD-HHMMSS.mka  トラック 1 = system、トラック 2 = mic (分離、Opus)
    DIR/YYYYMMDD-HHMMSS.opus 2 つをミックスした 1 本

      -o DIR     出力先 (既定 ~/Recordings)
      -s SOURCE  システム音声のソース名 (既定 @DEFAULT_MONITOR@)
      -m SOURCE  マイクのソース名 (既定 @DEFAULT_SOURCE@)
      -l         ソース名の一覧を表示して終了
    EOF
    }

    out_dir="$HOME/Recordings"
    system_src="@DEFAULT_MONITOR@"
    mic_src="@DEFAULT_SOURCE@"

    while getopts "o:s:m:lh" opt; do
      case "$opt" in
        o) out_dir="$OPTARG" ;;
        s) system_src="$OPTARG" ;;
        m) mic_src="$OPTARG" ;;
        l) pactl list short sources; exit 0 ;;
        *) usage; exit 2 ;;
      esac
    done

    mkdir -p "$out_dir"
    base="$out_dir/$(date +%Y%m%d-%H%M%S)"

    echo "system: $system_src"
    echo "mic:    $mic_src"
    echo "output: $base.mka / $base.opus (Ctrl-C で停止)"

    exec ffmpeg -hide_banner -loglevel warning -stats \
      -thread_queue_size 1024 -f pulse -i "$system_src" \
      -thread_queue_size 1024 -f pulse -i "$mic_src" \
      -filter_complex "\
    [0:a]aresample=48000:async=1,aformat=channel_layouts=stereo,asplit=2[s1][s2];\
    [1:a]aresample=48000:async=1,aformat=channel_layouts=stereo,asplit=2[m1][m2];\
    [s2][m2]amix=inputs=2:duration=longest:normalize=0[mix]" \
      -map "[s1]" -map "[m1]" -c:a libopus -b:a 48k \
      -metadata:s:a:0 title=system -metadata:s:a:1 title=mic "$base.mka" \
      -map "[mix]" -c:a libopus -b:a 64k "$base.opus"
  '';
}
