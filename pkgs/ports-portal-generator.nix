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

    {
      echo '<!doctype html>'
      echo '<html><head><meta charset="utf-8">'
      echo '<title>Listening Ports</title>'
      echo '<style>body{font-family:system-ui, sans-serif; margin:24px;} table{border-collapse:collapse;} th,td{border:1px solid #ddd; padding:6px 10px;} th{background:#f5f5f5;}</style>'
      echo '</head><body>'
      echo '<h1>Listening Ports</h1>'
      echo "<p>Updated: $(date -Is)</p>"
      echo '<table><thead><tr><th>Proto</th><th>Local Address</th><th>Port</th><th>Process</th><th>PID</th></tr></thead><tbody>'

      ss -lntupH | while read -r line; do
        proto=$(echo "$line" | awk '{print $1}')
        local_addr=$(echo "$line" | awk '{print $5}')
        addr=''${local_addr%:*}
        port=''${local_addr##*:}
        proc=$(echo "$line" | awk -F'users:' '{print $2}')
        pname=$(echo "$proc" | awk -F'"' '{print $2}')
        pid=$(echo "$proc" | awk -F'pid=' '{print $2}' | awk -F',' '{print $1}')
        echo "<tr><td>''${proto}</td><td>''${addr}</td><td>''${port}</td><td>''${pname}</td><td>''${pid}</td></tr>"
      done

      echo '</tbody></table>'
      echo '</body></html>'
    } > "$tmp"

    install -D -m 0644 "$tmp" "$out"
  '';

  meta = {
    description = "Generate an HTML page listing listening TCP/UDP ports";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "ports-portal-generator";
  };
}
