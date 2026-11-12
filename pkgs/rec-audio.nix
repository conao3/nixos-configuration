{
  writeShellApplication,
  ffmpeg,
  pulseaudio,
  pipewire,
}:
writeShellApplication {
  name = "rec-audio";
  runtimeInputs = [
    ffmpeg
    pulseaudio
    pipewire
  ];
  text = ''
    usage() {
      cat <<'EOF'
    usage: rec-audio [-o DIR] [-s SYSTEM_SOURCE] [-m MIC_SOURCE] [-l]

    システム音声 (すべての出力の monitor をまとめたもの) とマイク (既定の入力) を同時に録音する。Ctrl-C で停止。
    アプリが既定以外の出力 (イヤホンなど) へ音を送っても、録音中に出力を抜き差ししても、システム音声に入る。
    DIR/YYYYMMDD-HHMMSS.mka  トラック 1 = system、トラック 2 = mic (分離、Opus)
    DIR/YYYYMMDD-HHMMSS.opus 2 つをミックスした 1 本

      -o DIR     出力先 (既定 ~/Recordings)
      -s SOURCE  システム音声のソース名 (既定はすべての出力の monitor をまとめた仮想のソース)
      -m SOURCE  マイクのソース名 (既定 @DEFAULT_SOURCE@)
      -l         ソース名の一覧を表示して終了
    EOF
    }

    out_dir="$HOME/Recordings"
    system_src=""
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

    combine_pid=""
    combine_conf=""
    cleanup() {
      if [ -n "$combine_pid" ]; then
        kill "$combine_pid" 2>/dev/null || true
        wait "$combine_pid" 2>/dev/null || true
      fi
      if [ -n "$combine_conf" ]; then
        rm -f "$combine_conf"
      fi
    }
    trap cleanup EXIT

    if [ -z "$system_src" ]; then
      system_src="rec-audio-system-$$"
      combine_conf="$(mktemp --suffix=.conf)"
      cat > "$combine_conf" <<EOF
    context.spa-libs = {
        audio.convert.* = audioconvert/libspa-audioconvert
        support.*       = support/libspa-support
    }
    context.modules = [
        { name = libpipewire-module-rt flags = [ ifexists nofail ] }
        { name = libpipewire-module-protocol-native }
        { name = libpipewire-module-client-node }
        { name = libpipewire-module-adapter }
        { name = libpipewire-module-combine-stream
          args = {
              combine.mode = source
              node.name = "$system_src"
              node.description = "rec-audio system"
              combine.latency-compensate = false
              combine.props = { audio.position = [ FL FR ] node.virtual = true }
              stream.props = { stream.capture.sink = true }
              stream.rules = [
                  { matches = [ { media.class = "Audio/Sink" } ]
                    actions = { create-stream = { } } }
              ]
          }
        }
    ]
    EOF
      pipewire -c "$combine_conf" &
      combine_pid=$!
      for _ in $(seq 50); do
        if pactl list short sources | cut -f2 | grep -qx "$system_src"; then
          break
        fi
        sleep 0.1
      done
      if ! pactl list short sources | cut -f2 | grep -qx "$system_src"; then
        echo "rec-audio: システム音声の仮想のソース $system_src ができなかった" >&2
        exit 1
      fi
      echo "system: すべての出力の monitor ($system_src)"
      pactl list short sinks | cut -f2 | sed 's/^/  - /'
    else
      echo "system: $system_src"
    fi
    echo "mic:    $mic_src"
    echo "output: $base.mka / $base.opus (Ctrl-C で停止)"

    ffmpeg -hide_banner -loglevel warning -stats \
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
