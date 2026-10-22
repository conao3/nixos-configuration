{
  writeShellApplication,
  fetchurl,
  bc,
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
    bc
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
    #   VOICE_TYPE_SILENCE (止まるまでの無音秒数、既定 1.5)、VOICE_TYPE_MAX (最長秒数、既定 60)、
    #   VOICE_TYPE_THRESHOLD (話し始め・終わりと判定する音量、既定 1.5%)
    model="''${VOICE_TYPE_MODEL:-${model}}"
    lang="''${VOICE_TYPE_LANG:-en}"
    silence="''${VOICE_TYPE_SILENCE:-1.5}"
    max_seconds="''${VOICE_TYPE_MAX:-60}"
    threshold="''${VOICE_TYPE_THRESHOLD:-1.5%}"

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
    lock_file="$runtime_dir/voice-type.lock"
    rec_pid_file="$runtime_dir/voice-type.rec"

    notify() {
      notify-send --app-name=voice-type --expire-time=3000 "$@" || true
    }

    # 同時に 1 つだけ動かす (flock。プロセスが死ねば自動で解放される)。
    # 動作中にもう一度呼ばれたら、録音中なら録音を止め (文字起こしは先に起動した側が進める)、
    # 認識中なら何もしない。
    exec 9>"$lock_file"
    if ! flock -n 9; then
      if [ -s "$rec_pid_file" ] && kill -0 "$(cat "$rec_pid_file")" 2>/dev/null; then
        kill -INT "$(cat "$rec_pid_file")"
      else
        notify "処理中です" "前の認識が終わるまでお待ちください。"
      fi
      exit 0
    fi

    work="$(mktemp -d)"
    trap 'rm -rf "$work"; rm -f "$rec_pid_file"' EXIT

    # 診断用に、直近 1 回分の録音・認識結果・ログを残す
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/voice-type"
    mkdir -p "$state_dir"
    rm -f "$state_dir"/last.*
    log() { printf '%s %s\n' "$(date +%T)" "$*" >> "$state_dir/last.log"; }
    log "start model=$model lang=$lang silence=$silence"

    notify "録音中" "話してください。無音が続くと自動で止まります。"
    # silence: 音が出るまで待ち (1 回 0.1 秒・3%)、''${silence} 秒の無音で止める。trim で最長を抑える。
    # timeout は何も話さずに放置された場合の打ち切りで、INT は子 (rec) へ中継される。
    # ロックの fd (9) は子プロセスへ引き継がない
    timeout -s INT "$((max_seconds + 30))" \
      rec -q -r 16000 -c 1 -b 16 "$work/in.wav" \
      silence 1 0.1 "$threshold" 1 "$silence" "$threshold" trim 0 "$max_seconds" 9>&- &
    rec_pid=$!
    # 診断用: しきい値で切り取られる前の、録音開始から 4 秒間の最大音量を測る (マイクが音を拾えているかの確認)
    rec -q -r 16000 -c 1 -n trim 0 4 stat 2> "$work/level.txt" 9>&- &
    level_pid=$!
    echo "$rec_pid" > "$rec_pid_file"
    wait "$rec_pid" || true
    rm -f "$rec_pid_file"
    log "rec finished"
    wait "$level_pid" 2>/dev/null || true
    log "mic level (first 4 s): $(grep -E 'Maximum amplitude|RMS     amplitude' "$work/level.txt" | tr -s ' ' | tr '\n' ' ')"

    # 無音や極端に短い録音は、Whisper が "you" のような幻覚を出すので認識しない
    duration="$(soxi -D "$work/in.wav" 2>/dev/null || echo 0)"
    if [ ! -s "$work/in.wav" ] || [ "$(echo "$duration < 0.3" | bc -l 2>/dev/null || echo 1)" = 1 ]; then
      log "no audio recorded (duration=$duration)"
      notify "音声が録音されませんでした"
      exit 0
    fi

    # 短い発話でも認識されやすいよう、前に 0.3 秒・後ろに 1 秒の無音を足す
    sox "$work/in.wav" "$work/padded.wav" pad 0.3 1.0
    cp "$work/padded.wav" "$state_dir/last.wav"
    log "recorded $duration s (padded wav: $state_dir/last.wav)"

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
