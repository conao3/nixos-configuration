{
  pkgs,
  ...
}:
let
  gistId = "f6cf98f8e322b653534ac9af2e1eb38b";
  eosAddress = "100.110.183.107";
  probe = pkgs.writeText "sysmon-probe.sh" ''
    set -u
    read_cpu() {
      awk '/^cpu / {t=0; for (i=2; i<=NF; i++) t+=$i; print t, $5+$6}' /proc/stat
    }
    set -- $(read_cpu); t1=$1; i1=$2
    sleep 1
    set -- $(read_cpu); t2=$1; i2=$2
    cpu=$(awk -v dt=$((t2 - t1)) -v di=$((i2 - i1)) \
      'BEGIN { if (dt > 0) printf "%d", (dt - di) * 100 / dt + 0.5; else print 0 }')
    mem=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} \
      END { if (t > 0) printf "%d", (t - a) * 100 / t + 0.5 }' /proc/meminfo)
    echo "$cpu $mem"
  '';
  publish = pkgs.writeShellScript "sysmon-publish" ''
    set -u
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.bash
        pkgs.jq
        pkgs.gh
        pkgs.openssh
      ]
    }"

    state_dir="$HOME/.local/share/sysmon"
    state="$state_dir/history.json"
    mkdir -p "$state_dir"
    [ -s "$state" ] || echo '{"helios":{"cpu":[],"mem":[]},"eos":{"cpu":[],"mem":[]}}' > "$state"

    out_h=$(bash ${probe} 2>/dev/null) || out_h=""
    out_e=$(ssh -o ConnectTimeout=6 -o BatchMode=yes conao@${eosAddress} \
      'bash -s' < ${probe} 2>/dev/null) || out_e=""

    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    next=$(jq -c \
      --arg h "$out_h" --arg e "$out_e" --arg now "$now" '
      def upd(out): (out | split(" ") | map(select(length > 0))) as $p
        | if ($p | length) == 2
          then {online: true, cpu: ($p[0] | tonumber), mem: ($p[1] | tonumber),
                cpu_hist: ((.cpu + [$p[0] | tonumber]) | .[-60:]),
                mem_hist: ((.mem + [$p[1] | tonumber]) | .[-60:])}
          else {online: false, cpu: null, mem: null,
                cpu_hist: .cpu, mem_hist: .mem}
          end;
      {helios: (.helios | upd($h)), eos: (.eos | upd($e))}' "$state") || exit 1

    hist=$(echo "$next" | jq -c '{helios: {cpu: .helios.cpu_hist, mem: .helios.mem_hist},
                                 eos: {cpu: .eos.cpu_hist, mem: .eos.mem_hist}}')
    echo "$hist" > "$state"

    pub=$(echo "$next" | jq -c --arg now "$now" '{updated_at: $now, hosts: .}')
    payload=$(jq -cn --arg content "$pub" '{files: {"sysmon.json": {content: $content}}}')
    echo "$payload" | gh api -X PATCH "/gists/${gistId}" --input - >/dev/null
  '';
in
{
  systemd.user.services.sysmon-publish = {
    description = "Publish system monitor data to the widget Gist";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${publish}";
    };
  };

  systemd.user.timers.sysmon-publish = {
    description = "Run sysmon publish every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* *:*:00";
      Persistent = false;
    };
  };
}
