{
  lib,
  writeShellApplication,
  iproute2,
  gawk,
  coreutils,
}:
writeShellApplication {
  name = "ports-portal-generator";

  runtimeInputs = [
    iproute2
    gawk
    coreutils
  ];

  text = ''
    set -euo pipefail

    out="''${1:?usage: ports-portal-generator <output-file>}"
    tmp="$(mktemp)"
    updated_at="$(date -Is)"
    first=1

    json_escape() {
      printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
    }

    {
      ss -lntupH | while read -r line; do
        proto=$(echo "$line" | awk '{print $1}')
        local_addr=$(echo "$line" | awk '{print $5}')
        addr=''${local_addr%:*}
        port=''${local_addr##*:}
        ip_version="ipv6"
        proc=$(echo "$line" | awk -F'users:' '{print $2}')
        pname=$(echo "$proc" | awk -F'"' '{print $2}')
        pid=$(echo "$proc" | awk -F'pid=' '{print $2}' | awk -F',' '{print $1}')
        cwd="-"
        [ -n "$pname" ] || pname="-"
        [ -n "$pid" ] || pid="-"
        if printf '%s' "$pid" | grep -Eq '^[0-9]+$'; then
          cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)
          [ -n "$cwd" ] || cwd="-"
        fi
        if printf '%s' "$addr" | grep -q '\.'; then
          ip_version="ipv4"
        fi

        if [ "$first" -eq 0 ]; then
          printf ',\n'
        fi
        first=0
        printf '    {"proto":"%s","ipVersion":"%s","address":"%s","port":"%s","process":"%s","pid":"%s","cwd":"%s"}' \
          "$(json_escape "$proto")" \
          "$(json_escape "$ip_version")" \
          "$(json_escape "$addr")" \
          "$(json_escape "$port")" \
          "$(json_escape "$pname")" \
          "$(json_escape "$pid")" \
          "$(json_escape "$cwd")"
      done
    } > "$tmp.ports"

    {
      echo "{"
      printf '  "updatedAt": "%s",\n' "$(json_escape "$updated_at")"
      echo '  "ports": ['
      cat "$tmp.ports"
      echo
      echo "  ]"
      echo "}"
    } > "$tmp"

    install -D -m 0644 "$tmp" "$out"
  '';

  meta = {
    description = "Generate JSON listing listening TCP/UDP ports";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "ports-portal-generator";
  };
}
