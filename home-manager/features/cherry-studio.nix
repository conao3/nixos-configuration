{ pkgs, ... }:
let
  cliProxyApiProviderUrl = pkgs.writeShellApplication {
    name = "cherry-studio-cliproxyapi-url";
    runtimeInputs = [
      pkgs.awscli2
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      api_key="$(
        AWS_PROFILE=''${AWS_PROFILE:-conao3.dev.k8s} \
        AWS_REGION=''${AWS_REGION:-ap-northeast-1} \
          aws secretsmanager get-secret-value \
            --secret-id "''${CLIPROXYAPI_SECRET_ID:-dev-k8s-secret}" \
            --query SecretString \
            --output text \
          | jq -er '."cli-proxy-api-key"'
      )"

      payload="$(
        jq -cn \
          --arg id "sancode-dev-cli-proxy-api" \
          --arg name "sancode.dev CLIProxyAPI" \
          --arg baseUrl "https://dev-cli-proxy-api.sancode.dev/v1" \
          --arg apiKey "$api_key" \
          --arg type "openai" \
          '{ id: $id, name: $name, baseUrl: $baseUrl, apiKey: $apiKey, type: $type }'
      )"

      data="$(printf '%s' "$payload" | base64 --wrap=0 | tr '+/' '_-')"
      printf 'cherrystudio://providers/api-keys?v=1&data=%s\n' "$data"
    '';
  };

  cliProxyApiConfigure = pkgs.writeShellApplication {
    name = "cherry-studio-configure-cliproxyapi";
    runtimeInputs = [
      cliProxyApiProviderUrl
      pkgs.cherry-studio
      pkgs.util-linux
      pkgs.xdg-utils
    ];
    text = ''
      url="$(cherry-studio-cliproxyapi-url)"

      if ! pgrep -u "$(id -u)" -f '/opt/cherry-studio/resources/app.asar' >/dev/null; then
        setsid -f cherry-studio --no-sandbox >/tmp/cherry-studio-cliproxyapi.log 2>&1
        sleep 5
      fi

      xdg-open "$url" >>/tmp/cherry-studio-cliproxyapi.log 2>&1
    '';
  };
in
{
  home.packages = [
    cliProxyApiConfigure
    cliProxyApiProviderUrl
    pkgs.cherry-studio
  ];

  xdg.mimeApps.defaultApplications."x-scheme-handler/cherrystudio" = "cherry-studio.desktop";
}
