{
  pkgs,
  ...
}:
let
  boardGistId = "b301f3d44372d4977df4b1df2849377c";
in
{
  systemd.user.services.board-history-update = {
    description = "Publish Board task counts history to the widget Gist";
    serviceConfig = {
      Type = "oneshot";
      Environment = "PATH=%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
      ExecStart = "${pkgs.writeShellScript "board-history-update" ''
        set -u
        # The board is the local vb serve instance: BOARD_URL points
        # at 127.0.0.1:4100 (the same value the user session carries)
        # and vb authenticates with its local token. The tailnet URL
        # instead takes the remote path, which rejects this host.
        export BOARD_URL="http://127.0.0.1:4100/api/board"
        vb=/etc/profiles/per-user/conao/bin/vb

        count() {
          n=$("$vb" tasks work/ --state "$1" --limit 500 --json 2>/dev/null | ${pkgs.jq}/bin/jq '.tasks | length') || return 1
          [ -n "$n" ] || return 1
          echo "$n"
        }
        waiting=$(count waiting) || exit 1
        ready=$(count ready) || exit 1
        blocked=$(count blocked) || exit 1
        running=$(count claimed) || exit 1
        open=$((waiting + ready))

        state_dir="$HOME/.local/share/board-history"
        state="$state_dir/history.json"
        ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
        if [ ! -s "$state" ]; then
          # Seed from the Gist so the series continues seamlessly.
          ${pkgs.curl}/bin/curl -fsSL "https://gist.githubusercontent.com/conao3/${boardGistId}/raw/board-history.json" \
            | ${pkgs.jq}/bin/jq -c '{points: [.history[] | {at, o, b, r}]}' > "$state" \
            || echo '{"points":[]}' > "$state"
        fi

        now=$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
        history=$(${pkgs.jq}/bin/jq -c --arg at "$now" --argjson o "$open" --argjson b "$blocked" --argjson r "$running" \
          '.points = ((.points + [{at: $at, o: $o, b: $b, r: $r}]) | .[-1344:])' "$state") || exit 1
        echo "$history" > "$state"

        ${pkgs.jq}/bin/jq -cj --arg now "$now" --argjson o "$open" --argjson b "$blocked" --argjson r "$running" --slurpfile state "$state" \
          '{updated_at: $now, open: $o, blocked: $b, running: $r, history: $state[0].points}' \
          | ${pkgs.jq}/bin/jq -Rs '{files: {"board-history.json": {content: .}}}' \
          | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${boardGistId}" --input - >/dev/null
      ''}";
    };
  };

  systemd.user.timers.board-history-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";
      Persistent = true;
    };
  };
}
