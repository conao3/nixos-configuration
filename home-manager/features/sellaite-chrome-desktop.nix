{
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  sellaite = inputs.sellaite.packages.${system}.default;
  sellaiteChromeDesktop = pkgs.writeShellApplication {
    name = "sellaite-chrome-desktop";
    runtimeInputs = [
      sellaite
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      dir="''${SELLAITE_CHROME_DIR:-$XDG_RUNTIME_DIR/sellaite-chrome}"
      link="$dir/wayland-0"
      width="''${SELLAITE_CHROME_WIDTH:-1920}"
      height="''${SELLAITE_CHROME_HEIGHT:-1080}"

      coproc SERVER { exec sellaite mcp serve-mcp; }
      mcp_pid=$SERVER_PID
      server_in=''${SERVER[1]}
      server_out=''${SERVER[0]}

      stopping=0
      trap 'stopping=1; exec {server_in}>&-' TERM INT
      trap 'rm -f "$link"' EXIT

      send() {
        printf '%s\n' "$1" >&"$server_in"
      }

      send '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"sellaite-chrome-desktop","version":"1"}}}'
      send '{"jsonrpc":"2.0","method":"notifications/initialized"}'
      send "$(jq -cn --argjson w "$width" --argjson h "$height" \
        '{jsonrpc:"2.0",id:2,method:"tools/call",params:{name:"start_desktop",arguments:{width:$w,height:$h}}}')"

      response=""
      while IFS= read -r -t 120 -u "$server_out" line; do
        if [ "$(jq -r '.id // empty' <<<"$line")" = 2 ]; then
          response=$line
          break
        fi
      done
      if [ -z "$response" ]; then
        echo "sellaite-chrome-desktop: no start_desktop response from sellaite mcp serve-mcp" >&2
        exit 1
      fi
      if ! jq -e '(.error == null) and (.result.isError != true)' <<<"$response" >/dev/null; then
        echo "sellaite-chrome-desktop: start_desktop failed: $response" >&2
        exit 1
      fi
      info=$(jq -c '.result.content[0].text | fromjson' <<<"$response")
      runtime_dir=$(jq -r '.XdgRuntimeDir' <<<"$info")
      socket="$runtime_dir/$(jq -r '.WaylandDisplay' <<<"$info")"
      echo "sellaite-chrome-desktop: desktop $(jq -r '.Id' <<<"$info") at $socket, linked from $link" >&2

      mkdir -p "$dir"
      ln -sfn "$socket" "$link.tmp"
      mv -fT "$link.tmp" "$link"

      rc=0
      wait "$mcp_pid" || rc=$?
      while [ "$stopping" = 1 ] && kill -0 "$mcp_pid" 2>/dev/null; do
        rc=0
        wait "$mcp_pid" || rc=$?
      done
      for _ in $(seq 100); do
        [ -e "$runtime_dir" ] || break
        sleep 0.1
      done
      if [ "$stopping" = 1 ]; then
        exit 0
      fi
      echo "sellaite-chrome-desktop: sellaite mcp serve-mcp exited with status $rc" >&2
      exit 1
    '';
  };
in
{
  systemd.user.services.sellaite-chrome-desktop = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "sellaite desktop for chrome-devtools (Wayland socket at %t/sellaite-chrome/wayland-0)";
      X-SwitchMethod = "keep-old";
    };
    Service = {
      ExecStart = lib.getExe sellaiteChromeDesktop;
      KillMode = "mixed";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
