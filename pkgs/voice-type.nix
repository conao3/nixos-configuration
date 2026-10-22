{
  writeShellApplication,
  fetchurl,
  bc,
  coreutils,
  libnotify,
  sox,
  fcitx5,
  whisper-cpp,
  xdotool,
}:
let
  # base.en (148MB) は録音が小さい・訛りがあるときに誤認識が多く、small.en (465MB) の方が安定する
  # (実測: 7.9 秒の録音で base.en 約 1.3 秒、small.en 約 5 秒。8 スレッド)
  model = fetchurl {
    name = "ggml-small.en.bin";
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
    hash = "sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=";
  };
in
writeShellApplication {
  name = "voice-type";
  runtimeInputs = [
    bc
    coreutils
    libnotify
    sox
    fcitx5
    whisper-cpp
    xdotool
  ];
  text = ''
    # マイクで話した内容を whisper.cpp でローカルに文字起こしし、フォーカス中のウィンドウへ打ち込む (X11)。
    # Claude Code の /voice は認識言語が `language` 設定と共有で英語にできないため、その代わりに使う。
    # 押す (F9) → 話す → 無音が 3 秒続くと自動で録音を止める (F9 でいつでも手動停止) → 文字起こし → 入力。Enter は送らない。
    # 録音中にもう一度押すと、その時点で録音を止めて文字起こしに進む。
    #
    # 環境変数: VOICE_TYPE_MODEL (モデル)、VOICE_TYPE_LANG (既定 en)、
    #   VOICE_TYPE_SILENCE (止まるまでの無音秒数、既定 3。考えながら話しても途切れにくい長さ)、VOICE_TYPE_MAX (最長秒数、既定 60)、
    #   VOICE_TYPE_THRESHOLD (話し始め・終わりと判定する音量、増幅後で既定 2%)、
    #   VOICE_TYPE_GAIN (録音時の増幅、dB、既定 12)、VOICE_TYPE_THREADS (既定 8)、
    #   VOICE_TYPE_PROMPT (語彙のヒント。~/.config/voice-type/prompt.txt があればそちらを優先)
    model="''${VOICE_TYPE_MODEL:-${model}}"
    lang="''${VOICE_TYPE_LANG:-en}"
    # sox の silence は、小数点のない数 (3) をサンプル数と解釈する。秒で渡すため、必ず小数にする (3 → 3.0)
    silence="$(printf '%.1f' "''${VOICE_TYPE_SILENCE:-3}")"
    max_seconds="''${VOICE_TYPE_MAX:-60}"
    threshold="''${VOICE_TYPE_THRESHOLD:-2%}"
    # EarPods のマイクは入力が小さい (声のピークが 0.02〜0.2 程度) ので、録音時に増幅してから無音を判定する (dB、limiter 付き)
    gain="''${VOICE_TYPE_GAIN:-12}"
    threads="''${VOICE_TYPE_THREADS:-8}"
    # 語彙のヒント (Whisper の initial prompt)。話題に出てくる固有名詞や専門語を書いておくと、そのつづりで認識されやすい。
    # ~/.config/voice-type/prompt.txt があればその内容を使う (話題に合わせて書き換える)。
    prompt_file="''${XDG_CONFIG_HOME:-$HOME/.config}/voice-type/prompt.txt"
    if [ -s "$prompt_file" ]; then
      prompt="$(tr '\n' ' ' < "$prompt_file")"
    else
      prompt="''${VOICE_TYPE_PROMPT:-This is an English conversation about the Clojure programming language, Lisp, the JVM, macros, immutable data structures, ClojureScript, and the REPL.}"
    fi

    # voice-type --history [件数]: 直近の実行の「日時・録音の長さ・認識結果・音声ファイル」を一覧する (再生は `play <audio.wav>`)
    if [ "''${1:-}" = "--history" ]; then
      runs_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/voice-type/runs"
      # shellcheck disable=SC2012
      for dir in $(ls -1dt "$runs_dir"/* 2>/dev/null | head -n "''${2:-10}"); do
        printf '%s  %s\n  text : %s\n  audio: %s\n' \
          "$(basename "$dir")" \
          "$(grep -E 'recorded [0-9.]+ s|no audio recorded' "$dir/log" | tail -1 | cut -d' ' -f2- | sed -E 's/ \(padded.*//')" \
          "$(tr '\n' ' ' < "$dir/raw.txt" 2>/dev/null || echo '(認識なし)')" \
          "$dir/audio.wav"
      done
      exit 0
    fi

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
    lock_file="$runtime_dir/voice-type.lock"
    rec_pid_file="$runtime_dir/voice-type.rec"

    notify() {
      notify-send --app-name=voice-type --expire-time=3000 "$@" || true
    }

    # キーの自動リピートや二重押しで続けて呼ばれたときは無視する (前回の呼び出しから 1.5 秒以内)。
    # 無視した呼び出しも時刻を更新するので、押しっぱなしの間は最後まで無視される。
    last_file="$runtime_dir/voice-type.last"
    now_ms="$(date +%s%3N)"
    last_ms="$(cat "$last_file" 2>/dev/null || echo 0)"
    echo "$now_ms" > "$last_file"
    if [ $((now_ms - last_ms)) -lt 1500 ]; then
      exit 0
    fi

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

    # 診断用に、直近 20 回分の録音・認識結果・ログを残す (runs/<日時>/、最新は last への symlink)
    base_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/voice-type"
    state_dir="$base_dir/runs/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$state_dir"
    ln -sfn "$state_dir" "$base_dir/last"
    # shellcheck disable=SC2012
    ls -1dt "$base_dir"/runs/* | tail -n +21 | xargs -r rm -rf
    log() { printf '%s %s\n' "$(date +%T)" "$*" >> "$state_dir/log"; }
    log "start model=$model lang=$lang silence=$silence gain=$gain threshold=$threshold threads=$threads"
    log "prompt=[$prompt]"

    notify "録音中" "話してください。無音が $silence 秒続くと自動で止まります (F9 で今すぐ停止)。"
    # silence: 音が出るまで待ち (1 回 0.1 秒・3%)、''${silence} 秒の無音で止める。trim で最長を抑える。
    # timeout は何も話さずに放置された場合の打ち切りで、INT は子 (rec) へ中継される。
    # ロックの fd (9) は子プロセスへ引き継がない
    timeout -s INT "$((max_seconds + 30))" \
      rec -q -r 16000 -c 1 -b 16 "$work/in.wav" \
      gain -l "$gain" silence 1 0.1 "$threshold" 1 "$silence" "$threshold" trim 0 "$max_seconds" 9>&- &
    rec_pid=$!
    # 診断用: しきい値で切り取られる前の、録音全体の最大音量を測る (マイクが音を拾えているかの確認)
    timeout -s INT "$((max_seconds + 30))" rec -q -r 16000 -c 1 -n stat 2> "$work/level.txt" 9>&- &
    level_pid=$!
    echo "$rec_pid" > "$rec_pid_file"
    wait "$rec_pid" || true
    rm -f "$rec_pid_file"
    log "rec finished"
    kill -INT "$level_pid" 2>/dev/null || true
    wait "$level_pid" 2>/dev/null || true
    log "mic level (whole recording, before the silence gate): $(grep -E 'Maximum amplitude|RMS     amplitude' "$work/level.txt" | tr -s ' ' | tr '\n' ' ')"

    # 無音や極端に短い録音は、Whisper が "you" のような幻覚を出すので認識しない
    duration="$(soxi -D "$work/in.wav" 2>/dev/null || echo 0)"
    if [ ! -s "$work/in.wav" ] || [ "$(echo "$duration < 0.3" | bc -l 2>/dev/null || echo 1)" = 1 ]; then
      log "no audio recorded (duration=$duration)"
      notify "音声が録音されませんでした"
      exit 0
    fi

    # 短い発話でも認識されやすいよう、前に 0.3 秒・後ろに 1 秒の無音を足す。
    # 音量は norm -3 で正規化する (声が小さくても、Whisper には一定の音量で渡す)
    sox "$work/in.wav" "$work/padded.wav" pad 0.3 1.0 norm -3
    cp "$work/padded.wav" "$state_dir/audio.wav"
    log "recorded peak=$(soxi -V0 "$work/in.wav" >/dev/null 2>&1; sox "$work/in.wav" -n stat 2>&1 | awk '/Maximum amplitude/ {print $3}') (after gain)"
    log "recorded $duration s (padded wav: $state_dir/audio.wav)"

    notify "認識中"
    if ! whisper-cli -m "$model" -l "$lang" -t "$threads" -nt -np --prompt "$prompt" -f "$work/padded.wav" -otxt -of "$work/out" > "$state_dir/whisper.log" 2>&1; then
      log "whisper-cli failed (see whisper.log)"
    fi
    cp "$work/out.txt" "$state_dir/raw.txt" 2>/dev/null || true
    text="$(tr '\n' ' ' < "$work/out.txt" 2>/dev/null | sed -e 's/\[BLANK_AUDIO\]//g' -e 's/  */ /g' -e 's/^ //' -e 's/ $//')"
    log "text=[$text]"

    if [ -z "$text" ]; then
      notify "認識できませんでした" "録音と結果は $state_dir に残してあります"
      exit 0
    fi

    # xdotool type で打つと、日本語入力 (fcitx5 の SKK) がローマ字をかなに変換してしまう。
    # クリップボード経由の貼り付けは IME を通らないが、Claude Code では貼り付けが 1 つのかたまりになって
    # 編集できなくなる。そこで、打つ間だけ IME を切って (fcitx5-remote -c)、普通のキー入力として打ち、
    # 元が有効 (状態 2) だったなら戻す (-o)。
    ime_state="$(fcitx5-remote 2>/dev/null || echo 0)"
    log "ime state=$ime_state"
    if [ "$ime_state" = 2 ]; then
      fcitx5-remote -c || true
      sleep 0.2
    fi
    xdotool type --clearmodifiers --delay 2 -- "$text" || log "xdotool type failed"
    if [ "$ime_state" = 2 ]; then
      sleep 0.2
      fcitx5-remote -o || true
    fi
    log "typed"
  '';
}
