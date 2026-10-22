{
  writeShellApplication,
  fetchurl,
  linkFarm,
  coreutils,
  piper-tts,
  sox,
}:
let
  voiceName = "en_US-lessac-medium";
  baseUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium";
  # Piper はモデルと同じディレクトリの <モデル>.json を設定として読む
  voice = linkFarm "piper-voice-${voiceName}" [
    {
      name = "${voiceName}.onnx";
      path = fetchurl {
        url = "${baseUrl}/${voiceName}.onnx";
        hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
      };
    }
    {
      name = "${voiceName}.onnx.json";
      path = fetchurl {
        url = "${baseUrl}/${voiceName}.onnx.json";
        hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
      };
    }
  ];
in
writeShellApplication {
  name = "speak";
  runtimeInputs = [
    coreutils
    piper-tts
    sox
  ];
  text = ''
    # 英文をローカルの Piper で音声合成して再生する (英語の面接の質問などの読み上げ用)。
    #   speak "Tell me about the video."   /   echo "..." | speak
    # 新しい呼び出しが来たら、前の読み上げは止めて、最新のものだけを読む。
    # 環境変数: VOICE_SPEAK_RATE (話す速さ。length_scale で、1.0 が標準、大きいほど遅い)、
    #   VOICE_SPEAK_MODEL (モデル)
    model="''${VOICE_SPEAK_MODEL:-${voice}/${voiceName}.onnx}"
    rate="''${VOICE_SPEAK_RATE:-1.0}"

    if [ "$#" -gt 0 ]; then
      text="$*"
    else
      text="$(cat)"
    fi
    if [ -z "$text" ]; then
      exit 0
    fi

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
    latest_file="$runtime_dir/speak.latest"
    play_pid_file="$runtime_dir/speak.play"
    token="$$-$(date +%s%N)"

    # 最新の呼び出しだけを読む: 自分の token を記録し、再生中の前の読み上げを止める
    echo "$token" > "$latest_file"
    if [ -s "$play_pid_file" ] && kill -0 "$(cat "$play_pid_file")" 2>/dev/null; then
      kill "$(cat "$play_pid_file")" 2>/dev/null || true
    fi

    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT

    printf '%s' "$text" | piper -m "$model" --length-scale "$rate" -f "$work/speech.wav" >/dev/null 2>&1

    # 合成の間に、より新しい呼び出しが来ていたら読まない
    if [ "$(cat "$latest_file" 2>/dev/null)" != "$token" ]; then
      exit 0
    fi

    play -q "$work/speech.wav" &
    echo $! > "$play_pid_file"
    wait $! || true
  '';
}
