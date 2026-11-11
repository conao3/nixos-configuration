{
  pkgs,
  inputs,
  ...
}:
let
  llmQuota = inputs.rust-llm-quota.packages.${pkgs.stdenv.hostPlatform.system}.default;
  gistId = "d8f1032c67ac68b1b97a5b46f392c44f";
in
{
  systemd.user.services = {
    claude-usage-update = {
      description = "Publish Claude usage to the widget Gist";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "claude-usage-update" ''
          set -u
          config_dir="$HOME/.agents/.claude.conao3"
          [ -s "$config_dir/.credentials.json" ] || exit 0

          raw=$(CLAUDE_CONFIG_DIR="$config_dir" ${llmQuota}/bin/llm-quota usage get-claude-usage 2>/dev/null) || exit 0
          usage=$(echo "$raw" | ${pkgs.jq}/bin/jq -c '
            def win: if . == null then null else
              {utilization: .Utilization, resets_at: .ResetsAt,
               limit_dollars: .LimitDollars, used_dollars: .UsedDollars,
               remaining_dollars: .RemainingDollars, locked_reason: .LockedReason}
            end;
            {five_hour: (.Usage.FiveHour | win),
             seven_day: (.Usage.SevenDay | win),
             seven_day_opus: (.Usage.SevenDayOpus | win),
             seven_day_sonnet: (.Usage.SevenDaySonnet | win)}') || exit 0
          echo "$usage" | ${pkgs.jq}/bin/jq -e '.seven_day' >/dev/null 2>&1 || exit 0

          state_dir="$HOME/.local/share/claude-usage"
          state="$state_dir/history.json"
          ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
          [ -s "$state" ] || echo '{"points":[]}' > "$state"

          now=$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
          util=$(echo "$usage" | ${pkgs.jq}/bin/jq -r '.seven_day.utilization')
          history=$(${pkgs.jq}/bin/jq -c --arg at "$now" --argjson u "$util" \
            '.points = ((.points + [{at: $at, u: $u}]) | .[-2880:])' "$state") || exit 1
          echo "$history" > "$state"
          points=$(echo "$history" | ${pkgs.jq}/bin/jq -c '.points')

          shaped=$(echo "$usage" | ${pkgs.jq}/bin/jq -c --arg now "$now" --argjson history "$points" '
            def pace_points:
              (.seven_day.resets_at | gsub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) as $r
              | ($now | fromdateiso8601) as $n
              | ($r - 604800) as $s
              | [range($s; ([$n, $r] | min); 900)
                 | {at: strftime("%Y-%m-%dT%H:%M:%SZ"),
                    u: ((1000 - ((. - $s) / 604800 * 1000 | round)) / 10)}];
            {five_hour, seven_day, seven_day_opus, seven_day_sonnet,
             updated_at: $now,
             history: ($history | map({at: .at, u: (100 - .u)})),
             pace: pace_points}')
          payload=$(${pkgs.jq}/bin/jq -cn --arg content "$shaped" \
            '{files: {"claude-usage.json": {content: $content}}}')
          echo "$payload" | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${gistId}" --input - >/dev/null 2>&1 || {
            ${pkgs.coreutils}/bin/sleep 20
            echo "$payload" | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${gistId}" --input - >/dev/null
          }
        ''}";
      };
    };

    opencode-usage-update = {
      description = "Publish OpenCode Go usage to the widget Gist";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "opencode-usage-update" ''
          set -u
          export OPENCODE_DB="$HOME/.agents/.opencode.agent001/opencode.db"
          [ -s "$OPENCODE_DB" ] || exit 0

          raw=$(${llmQuota}/bin/llm-quota usage get-opencode-usage 2>/dev/null) || exit 0
          echo "$raw" | ${pkgs.jq}/bin/jq -e '.Summary.Week.PercentLeft != null and .Summary.Month.PercentLeft != null' >/dev/null 2>&1 || exit 0

          state_dir="$HOME/.local/share/opencode-usage"
          state="$state_dir/history.json"
          month_state="$state_dir/month-history.json"
          ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
          [ -s "$state" ] || echo '{"points":[]}' > "$state"
          [ -s "$month_state" ] || echo '{"points":[]}' > "$month_state"

          now=$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
          used=$(echo "$raw" | ${pkgs.jq}/bin/jq -r '100 - .Summary.Week.PercentLeft')
          history=$(${pkgs.jq}/bin/jq -c --arg at "$now" --argjson u "$used" \
            '.points = ((.points + [{at: $at, u: $u}]) | .[-2880:])' "$state") || exit 1
          echo "$history" > "$state"
          points=$(echo "$history" | ${pkgs.jq}/bin/jq -c '.points')

          month_used=$(echo "$raw" | ${pkgs.jq}/bin/jq -r '100 - .Summary.Month.PercentLeft')
          month_history=$(${pkgs.jq}/bin/jq -c --arg at "$now" --argjson u "$month_used" \
            '.points = ((.points + [{at: $at, u: $u}]) | .[-2880:])' "$month_state") || exit 1
          echo "$month_history" > "$month_state"
          month_points=$(echo "$month_history" | ${pkgs.jq}/bin/jq -c '.points')

          shaped=$(echo "$raw" | ${pkgs.jq}/bin/jq -c --arg now "$now" --argjson history "$points" --argjson month_history "$month_points" '
            def win: if . == null then null else
              {used_usd: .UsedUsd, limit_usd: .LimitUsd,
               percent_left: .PercentLeft, resets_at: .ResetsAt}
            end;
            def toepoch: gsub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601;
            def pace_points($reset; $secs):
              ($reset | toepoch) as $r
              | ($now | fromdateiso8601) as $n
              | ($r - $secs) as $s
              | [range($s; ([$n, $r] | min); 900)
                 | {at: strftime("%Y-%m-%dT%H:%M:%SZ"),
                    u: ((1000 - ((. - $s) / $secs * 1000 | round)) / 10)}];
            def month_window_secs:
              (.Summary.Month.ResetsAt | toepoch) as $r
              | (($r | gmtime)
                 | (if .[1] == 0
                    then [.[0] - 1, 11, .[2], .[3], .[4], .[5], .[6], .[7]]
                    else [.[0], .[1] - 1, .[2], .[3], .[4], .[5], .[6], .[7]]
                    end)
                 | mktime) as $s
              | ($r - $s);
            {updated_at: $now,
             five_hour: (.Summary.FiveHour | win),
             week: (.Summary.Week | win),
             month: (.Summary.Month | win),
             history: ($history | map({at: .at, u: (100 - .u)})),
             pace: pace_points(.Summary.Week.ResetsAt; 604800),
             month_history: ($month_history | map({at: .at, u: (100 - .u)})),
             month_pace: pace_points(.Summary.Month.ResetsAt; month_window_secs)}')
          payload=$(${pkgs.jq}/bin/jq -cn --arg content "$shaped" \
            '{files: {"opencode-usage.json": {content: $content}}}')
          echo "$payload" | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${gistId}" --input - >/dev/null 2>&1 || {
            ${pkgs.coreutils}/bin/sleep 20
            echo "$payload" | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${gistId}" --input - >/dev/null
          }
        ''}";
      };
    };
  };

  systemd.user.timers = {
    claude-usage-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };

    opencode-usage-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:02/15";
        Persistent = true;
      };
    };
  };
}
