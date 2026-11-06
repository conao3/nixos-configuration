APP_NAME="text-llm"
FUNCTION_NAME="serve"
CONFIG_DIR="$HOME/.config/text-llm"
KEY_FILE="$CONFIG_DIR/api-key"
OPENCODE_CONFIG_FILE="$CONFIG_DIR/opencode.json"
SECRET_NAME="text-llm-api-key"
OPENCODE_PROVIDER="text-llm"
OPENCODE_OUTPUT_LIMIT=32768
REQUEST_TIMEOUT=160

usage() {
  cat <<'EOF'
Usage: modal-llm <command> [args]

Run the self-hosted text LLM (vLLM on Modal) and wire it into OpenCode / T3 Code.

Daily use:
  up                  warm up the endpoint and wait until it answers (cold start takes 5-6 min)
  status              show running containers and this month's usage
  down                stop the running containers and wait until they are gone
  chat <prompt>...    send one prompt and print the answer, the time and the tokens
                      (--think keeps the model's thinking on)
  logs                follow the server logs (Ctrl-C to quit)
  cost [today|week|month]
                      show the cost per resource (default: today)

Setup:
  init                create the API key file and the Modal secret when they are missing
  deploy              deploy the packaged app.py and rewrite the OpenCode config
  opencode-config     write the OpenCode provider config to ~/.config/text-llm/opencode.json
  reload-opencode     stop the OpenCode servers that T3 Code started with that config,
                      so the next thread reads the new config
  url                 print the endpoint URL
  env                 print shell exports for OpenAI-compatible clients
  app-file            print the path of the packaged app.py
EOF
}

die() {
  echo "modal-llm: error: $1" >&2
  exit 1
}

app_value() {
  local value
  value=$(sed -n "s/^$1 = \"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" "$APP_FILE")
  [ -n "$value" ] || die "$1 is not set in $APP_FILE"
  echo "$value"
}

endpoint_url() {
  python -c "import modal; print(modal.Function.from_name('$APP_NAME', '$FUNCTION_NAME').get_web_url())"
}

api_key() {
  [ -r "$KEY_FILE" ] || die "API key file $KEY_FILE is missing; run: modal-llm init"
  cat "$KEY_FILE"
}

containers() {
  modal container list --json | jq -r --arg app "$APP_NAME" '.[] | select(.app_name == $app) | .container_id'
}

elapsed_since() {
  echo $(($(date +%s) - $1))
}

post_until_ready() {
  local url="$1" body="$2" out="$3" key code start
  key=$(api_key)
  start=$(date +%s)
  for _ in $(seq 1 10); do
    code=$(curl -s -o "$out" -w '%{http_code}' --max-time "$REQUEST_TIMEOUT" \
      -H "Authorization: Bearer $key" -H 'Content-Type: application/json' \
      ${body:+-d "$body"} "$url" || true)
    if [ "$code" = 200 ]; then
      return 0
    fi
    if [ "$code" != 303 ] && [ "$code" != 000 ]; then
      die "HTTP $code from $url: $(head -c 300 "$out")"
    fi
    echo "waiting: cold start ($(elapsed_since "$start")s)" >&2
    sleep 5
  done
  die "not ready after $(elapsed_since "$start")s; check: modal-llm logs"
}

cmd_up() {
  local url start out
  url=$(endpoint_url)
  out=$(mktemp)
  start=$(date +%s)
  post_until_ready "$url/v1/models" "" "$out"
  rm -f "$out"
  echo "ready ($(elapsed_since "$start")s): $url"
}

cmd_status() {
  local ids month
  mapfile -t ids < <(containers)
  if [ "${#ids[@]}" -eq 0 ]; then
    echo "containers: none (not billing)"
  else
    echo "containers: ${#ids[@]} running"
    printf '  %s\n' "${ids[@]}"
  fi
  month=$(modal billing report --for "this month" --json | jq -r '[.[].cost | tonumber] | add // 0 | . * 100 | round / 100')
  echo "usage this month: \$$month (the included credits cover up to the usage limit)"
}

cmd_down() {
  local ids
  mapfile -t ids < <(containers)
  for id in "${ids[@]}"; do
    modal container stop -y "$id"
  done
  for _ in $(seq 1 12); do
    if [ -z "$(containers)" ]; then
      echo "containers: none"
      return 0
    fi
    sleep 5
  done
  die "still running: $(containers)"
}

cmd_chat() {
  local think=false prompt url body out start
  if [ "${1:-}" = "--think" ]; then
    think=true
    shift
  fi
  prompt="$*"
  [ -n "$prompt" ] || die "usage: modal-llm chat [--think] <prompt>"
  url=$(endpoint_url)
  body=$(jq -n --arg model "$(app_value SERVED_NAME)" --arg prompt "$prompt" --argjson think "$think" \
    '{model: $model, messages: [{role: "user", content: $prompt}], chat_template_kwargs: {enable_thinking: $think}}')
  out=$(mktemp)
  start=$(date +%s)
  post_until_ready "$url/v1/chat/completions" "$body" "$out"
  jq -r '.choices[0].message.content' "$out"
  jq -r --arg t "$(elapsed_since "$start")" \
    '"(\($t)s, prompt \(.usage.prompt_tokens) / completion \(.usage.completion_tokens) tokens, finish \(.choices[0].finish_reason))"' "$out" >&2
  rm -f "$out"
}

cmd_cost() {
  local period
  case "${1:-today}" in
    today) period="today" ;;
    week) period="this week" ;;
    month) period="this month" ;;
    *) die "usage: modal-llm cost [today|week|month]" ;;
  esac
  modal billing report --for "$period" --show-resources --json |
    jq -r 'group_by(.resource) | map({resource: .[0].resource, cost: (map(.cost | tonumber) | add)}) | sort_by(-.cost)
      | (map("\(.resource)\t$\(.cost * 10000 | round / 10000)") | .[]), "total\t$\(map(.cost) | add // 0 | . * 10000 | round / 10000)"'
}

cmd_init() {
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  if [ ! -s "$KEY_FILE" ]; then
    (umask 077 && openssl rand -hex 32 >"$KEY_FILE")
    echo "created $KEY_FILE"
  fi
  if modal secret list --json | jq -e --arg name "$SECRET_NAME" 'any(.[]; .name == $name)' >/dev/null; then
    echo "Modal secret $SECRET_NAME exists"
  else
    modal secret create "$SECRET_NAME" "VLLM_API_KEY=$(api_key)" >/dev/null
    echo "created Modal secret $SECRET_NAME"
  fi
}

cmd_opencode_config() {
  local url model context
  url=$(endpoint_url)
  model=$(app_value SERVED_NAME)
  context=$(app_value MAX_MODEL_LEN)
  mkdir -p "$CONFIG_DIR"
  jq -n --arg provider "$OPENCODE_PROVIDER" --arg url "$url/v1" --arg key "{file:$KEY_FILE}" --arg model "$model" \
    --argjson context "$context" --argjson output "$OPENCODE_OUTPUT_LIMIT" '{
      "$schema": "https://opencode.ai/config.json",
      provider: {
        ($provider): {
          npm: "@ai-sdk/openai-compatible",
          name: "Modal text-llm",
          options: {baseURL: $url, apiKey: $key, timeout: 600000},
          models: {
            ($model): {
              name: "\($model) (Modal)",
              tool_call: true,
              reasoning: true,
              limit: {context: $context, output: $output}
            }
          }
        }
      }
    }' >"$OPENCODE_CONFIG_FILE"
  echo "wrote $OPENCODE_CONFIG_FILE (model $OPENCODE_PROVIDER/$model, context $context, output $OPENCODE_OUTPUT_LIMIT)"
}

cmd_reload_opencode() {
  local stopped=0
  for pid in $(pgrep -f 'opencode serve' || true); do
    if tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | grep -qx "OPENCODE_CONFIG=$OPENCODE_CONFIG_FILE"; then
      kill "$pid"
      stopped=$((stopped + 1))
    fi
  done
  echo "stopped $stopped OpenCode server(s); the next T3 Code thread starts a new one"
}

cmd_deploy() {
  modal deploy "$APP_FILE"
  cmd_opencode_config
}

cmd_env() {
  echo "export OPENAI_BASE_URL=$(endpoint_url)/v1"
  echo "export OPENAI_API_KEY=\$(cat $KEY_FILE)"
  echo "export OPENAI_MODEL=$(app_value SERVED_NAME)"
}

case "${1:-}" in
  up) cmd_up ;;
  status) cmd_status ;;
  down) cmd_down ;;
  chat) shift && cmd_chat "$@" ;;
  logs) exec modal app logs "$APP_NAME" ;;
  cost) shift && cmd_cost "$@" ;;
  init) cmd_init ;;
  deploy) cmd_deploy ;;
  opencode-config) cmd_opencode_config ;;
  reload-opencode) cmd_reload_opencode ;;
  url) endpoint_url ;;
  env) cmd_env ;;
  app-file) echo "$APP_FILE" ;;
  -h | --help | help) usage ;;
  *) usage >&2 && exit 2 ;;
esac
