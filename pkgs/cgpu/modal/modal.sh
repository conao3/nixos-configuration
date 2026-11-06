APP_FILE="$MODAL_DIR/app.py"
MODELS_DIR="$MODAL_DIR/models"
CONFIG_DIR="$HOME/.config/cgpu/modal"
KEY_FILE="$CONFIG_DIR/api-key"
OPENCODE_CONFIG_FILE="$CONFIG_DIR/opencode.json"
SECRET_NAME="cgpu-api-key"
FUNCTION_NAME="serve"
REQUEST_TIMEOUT=160

usage() {
  cat <<'EOF'
Usage: cgpu modal <command> [options]

Run self-hosted LLMs (vLLM) on Modal, one Modal app (cgpu-<model>) per model.

Daily use:
  list                              list the models and whether each has running containers
  up --model <m>                    warm up the endpoint and wait until it answers
  status [--model <m>]              running containers, requests in progress, this month's usage
  down --model <m> [--force]        stop the running containers and wait until they are gone; refuses
                                    while requests are in progress or a container is still starting
  chat --model <m> [--think] <prompt>...
                                    send one prompt and print the answer, the time and the tokens
  logs --model <m>                  follow the server logs (Ctrl-C to quit)
  cost [today|week|month] [--model <m>]
                                    cost per app and resource (default: today)

Setup:
  init                              create the API key file and the Modal secret when they are missing
  deploy --model <m> | --all        deploy the model app(s) and rewrite the OpenCode config
  opencode-config                   write the OpenCode providers for all models to
                                    ~/.config/cgpu/modal/opencode.json
  reload-opencode                   stop the OpenCode servers that T3 Code started with that config
  url --model <m>                   print the endpoint URL
  env --model <m>                   print shell exports for OpenAI-compatible clients
EOF
}

die() {
  echo "cgpu modal: error: $1" >&2
  exit 1
}

model_names() {
  local f
  for f in "$MODELS_DIR"/*.json; do
    basename "$f" .json
  done
}

require_model() {
  [ -n "$1" ] || die "--model is required (models: $(model_names | tr '\n' ' '))"
  [ -f "$MODELS_DIR/$1.json" ] || die "unknown model '$1' (models: $(model_names | tr '\n' ' '))"
}

spec() {
  jq -c --arg name "$1" '. + {name: $name}' "$MODELS_DIR/$1.json"
}

spec_value() {
  jq -r --arg key "$2" '.[$key]' "$MODELS_DIR/$1.json"
}

app_name() {
  echo "cgpu-$1"
}

endpoint_url() {
  python -c "import modal, sys; print(modal.Function.from_name(sys.argv[1], sys.argv[2]).get_web_url())" "$(app_name "$1")" "$FUNCTION_NAME"
}

api_key() {
  [ -r "$KEY_FILE" ] || die "API key file $KEY_FILE is missing; run: cgpu modal init"
  cat "$KEY_FILE"
}

containers() {
  modal container list --json | jq -r --arg app "$(app_name "$1")" '.[] | select(.app_name == $app) | .container_id'
}

elapsed_since() {
  echo $(($(date +%s) - $1))
}

in_flight() {
  local metrics
  metrics=$(curl -s --max-time 10 -H "Authorization: Bearer $(api_key)" "$(endpoint_url "$1")/metrics") || return 1
  [ -n "$metrics" ] || return 1
  echo "$metrics" | awk '/^vllm:num_requests_(running|waiting)[{ ]/ { n += $NF } END { printf "%d\n", n }'
}

request_until_ready() {
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
  die "not ready after $(elapsed_since "$start")s; check: cgpu modal logs --model <m>"
}

cmd_list() {
  local name ids
  for name in $(model_names); do
    mapfile -t ids < <(containers "$name")
    printf '%s\t%s\t%s\tcontainers=%d\n' "$name" "$(spec_value "$name" served_name)" "$(spec_value "$name" gpu)" "${#ids[@]}"
  done
}

cmd_up() {
  local model="$1" url start out
  require_model "$model"
  url=$(endpoint_url "$model")
  out=$(mktemp)
  start=$(date +%s)
  request_until_ready "$url/v1/models" "" "$out"
  rm -f "$out"
  echo "ready ($(elapsed_since "$start")s): $url"
}

model_status() {
  local name="$1" ids requests
  mapfile -t ids < <(containers "$name")
  if [ "${#ids[@]}" -eq 0 ]; then
    echo "$name: no containers (not billing)"
    return 0
  fi
  echo "$name: ${#ids[@]} container(s)"
  printf '  %s\n' "${ids[@]}"
  if requests=$(in_flight "$name"); then
    echo "  requests in progress: $requests"
  else
    echo "  requests in progress: unknown (the server is still starting)"
  fi
}

cmd_status() {
  local model="$1" name month
  if [ -n "$model" ]; then
    require_model "$model"
    model_status "$model"
  else
    for name in $(model_names); do
      model_status "$name"
    done
  fi
  month=$(modal billing report --for "this month" --json | jq -r '[.[].cost | tonumber] | add // 0 | . * 100 | round / 100')
  echo "workspace usage this month: \$$month (the included credits cover up to the usage limit)"
}

cmd_down() {
  local model="$1" force="$2" ids requests
  require_model "$model"
  mapfile -t ids < <(containers "$model")
  if [ "${#ids[@]}" -gt 0 ] && [ "$force" != true ]; then
    if ! requests=$(in_flight "$model"); then
      die "a container is still starting, likely for a waiting request; rerun with --force to stop it anyway"
    fi
    if [ "$requests" -gt 0 ]; then
      die "$requests request(s) in progress; rerun with --force to stop anyway"
    fi
  fi
  for id in "${ids[@]}"; do
    modal container stop -y "$id"
  done
  for _ in $(seq 1 12); do
    if [ -z "$(containers "$model")" ]; then
      echo "$model: no containers"
      return 0
    fi
    sleep 5
  done
  die "still running: $(containers "$model")"
}

cmd_chat() {
  local model="$1" think="$2" prompt="$3" url body out start
  require_model "$model"
  [ -n "$prompt" ] || die "usage: cgpu modal chat --model <m> [--think] <prompt>"
  url=$(endpoint_url "$model")
  body=$(jq -n --arg model "$(spec_value "$model" served_name)" --arg prompt "$prompt" --argjson think "$think" \
    '{model: $model, messages: [{role: "user", content: $prompt}], chat_template_kwargs: {enable_thinking: $think}}')
  out=$(mktemp)
  start=$(date +%s)
  request_until_ready "$url/v1/chat/completions" "$body" "$out"
  jq -r '.choices[0].message.content' "$out"
  jq -r --arg t "$(elapsed_since "$start")" \
    '"(\($t)s, prompt \(.usage.prompt_tokens) / completion \(.usage.completion_tokens) tokens, finish \(.choices[0].finish_reason))"' "$out" >&2
  rm -f "$out"
}

cmd_cost() {
  local period="$1" model="$2" filter=""
  case "${period:-today}" in
    today) period="today" ;;
    week) period="this week" ;;
    month) period="this month" ;;
    *) die "usage: cgpu modal cost [today|week|month] [--model <m>]" ;;
  esac
  if [ -n "$model" ]; then
    require_model "$model"
    filter=$(app_name "$model")
  fi
  modal billing report --for "$period" --show-resources --json |
    jq -r --arg app "$filter" '
      map(select($app == "" or .description == $app))
      | (group_by(.description + "\t" + .resource)
        | map({key: (.[0].description + "\t" + .[0].resource), cost: (map(.cost | tonumber) | add)})
        | sort_by(-.cost) | .[] | "\(.key)\t$\(.cost * 10000 | round / 10000)"),
        "total\t\t$\(map(.cost | tonumber) | add // 0 | . * 10000 | round / 10000)"'
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
  local name providers="{}" url provider
  for name in $(model_names); do
    url=$(endpoint_url "$name") || die "model '$name' is not deployed; run: cgpu modal deploy --model $name"
    provider=$(jq -c --arg url "$url/v1" --arg key "{file:$KEY_FILE}" '{
        npm: "@ai-sdk/openai-compatible",
        name: "cgpu modal",
        options: {baseURL: $url, apiKey: $key, timeout: 600000},
        models: {
          (.served_name): {
            name: "\(.served_name) (Modal)",
            tool_call: .opencode.tool_call,
            reasoning: .opencode.reasoning,
            limit: {context: .max_model_len, output: .opencode.output}
          }
        }
      }' "$MODELS_DIR/$name.json")
    providers=$(jq -c --arg name "$name" --argjson provider "$provider" '. + {($name): $provider}' <<<"$providers")
  done
  mkdir -p "$CONFIG_DIR"
  jq -n --argjson providers "$providers" '{"$schema": "https://opencode.ai/config.json", provider: $providers}' >"$OPENCODE_CONFIG_FILE"
  echo "wrote $OPENCODE_CONFIG_FILE ($(jq -r '.provider | to_entries | map("\(.key)/\(.value.models | keys[0])") | join(", ")' "$OPENCODE_CONFIG_FILE"))"
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
  local model="$1" all="$2" name
  if [ "$all" = true ]; then
    for name in $(model_names); do
      CGPU_MODEL_SPEC=$(spec "$name") modal deploy "$APP_FILE"
    done
  else
    require_model "$model"
    CGPU_MODEL_SPEC=$(spec "$model") modal deploy "$APP_FILE"
  fi
  cmd_opencode_config
}

cmd_env() {
  local model="$1"
  require_model "$model"
  echo "export OPENAI_BASE_URL=$(endpoint_url "$model")/v1"
  echo "export OPENAI_API_KEY=\$(cat $KEY_FILE)"
  echo "export OPENAI_MODEL=$(spec_value "$model" served_name)"
}

command="${1:-}"
[ "$#" -gt 0 ] && shift
model=""
force=false
think=false
all=false
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -m | --model)
      [ "$#" -ge 2 ] || die "--model needs a value"
      model="$2"
      shift 2
      ;;
    --model=*)
      model="${1#--model=}"
      shift
      ;;
    --force)
      force=true
      shift
      ;;
    --think)
      think=true
      shift
      ;;
    --all)
      all=true
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

case "$command" in
  list) cmd_list ;;
  up) cmd_up "$model" ;;
  status) cmd_status "$model" ;;
  down) cmd_down "$model" "$force" ;;
  chat) cmd_chat "$model" "$think" "${args[*]:-}" ;;
  logs)
    require_model "$model"
    exec modal app logs "$(app_name "$model")"
    ;;
  cost) cmd_cost "${args[0]:-}" "$model" ;;
  init) cmd_init ;;
  deploy) cmd_deploy "$model" "$all" ;;
  opencode-config) cmd_opencode_config ;;
  reload-opencode) cmd_reload_opencode ;;
  url)
    require_model "$model"
    endpoint_url "$model"
    ;;
  env) cmd_env "$model" ;;
  -h | --help | help | "") usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
