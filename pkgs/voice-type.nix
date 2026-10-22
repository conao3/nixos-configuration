{
  writeShellApplication,
  fetchurl,
  coreutils,
  libnotify,
  sox,
  whisper-cpp,
  xdotool,
}:
let
  # overhear (conao3/rust-overhear) の flake と同じモデル
  model = fetchurl {
    name = "ggml-base.en.bin";
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
in
writeShellApplication {
  name = "voice-type";
  runtimeInputs = [
    coreutils
    libnotify
    sox
    whisper-cpp
    xdotool
  ];
  text = ''
    # マイクで話した内容を whisper.cpp でローカルに文字起こしし、フォーカス中のウィンドウへ打ち込む (X11)。
    # Claude Code の /voice は認識言語が `language` 設定と共有で英語にできないため、その代わりに使う。
    # 押す (F9) → 話す → 無音が続くと自動で録音を止める → 文字起こし → 入力。Enter は送らない。
    # 録音中にもう一度押すと、その時点で録音を止めて文字起こしに進む。
    #
    # 環境変数: VOICE_TYPE_MODEL (モデル)、VOICE_TYPE_LANG (既定 en)、
    #   VOICE_TYPE_SILENCE (止まるまでの無音秒数、既定 1.5)、VOICE_TYPE_MAX (最長秒数、既定 60)
    model="''${VOICE_TYPE_MODEL:-${model}}"
    lang="''${VOICE_TYPE_LANG:-en}"
    silence="''${VOICE_TYPE_SILENCE:-1.5}"
    max_seconds="''${VOICE_TYPE_MAX:-60}"

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
    pid_file="$runtime_dir/voice-type.pid"

    notify() {
      notify-send --app-name=voice-type --expire-time=3000 "$@" || true
    }

    # 録音中に再度呼ばれたら、録音を止めて終わる (文字起こしは先に起動した側が進める)
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
      kill -INT "$(cat "$pid_file")"
      exit 0
    fi

    work="$(mktemp -d)"
    trap 'rm -rf "$work"; rm -f "$pid_file"' EXIT

    # 診断用に、直近 1 回分の録音・認識結果・ログを残す
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/voice-type"
    mkdir -p "$state_dir"
    rm -f "$state_dir"/last.*
    log() { printf '%s %s\n' "$(date +%T)" "$*" >> "$state_dir/last.log"; }
    log "start model=$model lang=$lang silence=$silence"

    notify "録音中" "話してください。無音が続くと自動で止まります。"
    # silence: 音が出るまで待ち (1 回 0.1 秒・3%)、${"$"}{silence} 秒の無音で止める。trim で最長を抑える
    rec -q -r 16000 -c 1 -b 16 "$work/in.wav" \
      silence 1 0.1 3% 1 "$silence" 3% trim 0 "$max_seconds" &
    echo $! > "$pid_file"
    # 何も話さずに放置された場合の打ち切り
    ( sleep 30; kill -INT "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null || true ) &
    watchdog=$!
    wait "$(cat "$pid_file")" || true
    kill "$watchdog" 2>/dev/null || true
    rm -f "$pid_file"

    if [ ! -s "$work/in.wav" ]; then
      log "no audio recorded"
      notify "音声が録音されませんでした"
      exit 0
    fi

    # 短い発話でも認識されやすいよう、前に 0.3 秒・後ろに 1 秒の無音を足す
    sox "$work/in.wav" "$work/padded.wav" pad 0.3 1.0
    cp "$work/padded.wav" "$state_dir/last.wav"
    log "recorded $(soxi -D "$work/in.wav" 2>/dev/null || echo '?') s (padded wav: $state_dir/last.wav)"

    notify "認識中"
    if ! whisper-cli -m "$model" -l "$lang" -t 4 -nt -np -f "$work/padded.wav" -otxt -of "$work/out" > "$state_dir/last.whisper.log" 2>&1; then
      log "whisper-cli failed (see last.whisper.log)"
    fi
    cp "$work/out.txt" "$state_dir/last.raw.txt" 2>/dev/null || true
    text="$(tr '\n' ' ' < "$work/out.txt" 2>/dev/null | sed -e 's/\[BLANK_AUDIO\]//g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//')"
    log "text=[$text]"

    if [ -z "$text" ]; then
      notify "認識できませんでした" "録音と結果は $state_dir に残してあります"
      exit 0
    fi

    xdotool type --clearmodifiers --delay 2 -- "$text" || log "xdotool type failed"
    log "typed"
  '';
}
