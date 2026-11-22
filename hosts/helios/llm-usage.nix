{
  pkgs,
  inputs,
  ...
}:
let
  llmQuota = inputs.rust-llm-quota.packages.${pkgs.stdenv.hostPlatform.system}.default;
  claudeGistId = "d8f1032c67ac68b1b97a5b46f392c44f";
  opencodeGistId = "9e942331b1843bd4acb90c293050f493";
  codexGistId = "c2736936496e866768fb6cb331fdaa8a";
  devinGistId = "44fd43e5011bd936361b706b76bb7a3f";
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

          echo "$usage" | ${pkgs.jq}/bin/jq -cj --arg now "$now" --slurpfile state "$state" '
            def pace_points:
              (.seven_day.resets_at | gsub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) as $r
              | ($now | fromdateiso8601) as $n
              | ($r - 604800) as $s
              | [range($s; ([$n, $r] | min); 900)
                 | {at: strftime("%Y-%m-%dT%H:%M:%SZ"),
                    u: ((1000 - ((. - $s) / 604800 * 1000 | round)) / 10)}];
            {five_hour, seven_day, seven_day_opus, seven_day_sonnet,
             updated_at: $now,
             history: ($state[0].points | map({at: .at, u: (100 - .u)})),
             pace: pace_points}' | ${pkgs.jq}/bin/jq -Rs '{files: {"claude-usage.json": {content: .}}}' | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${claudeGistId}" --input - >/dev/null
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

          month_used=$(echo "$raw" | ${pkgs.jq}/bin/jq -r '100 - .Summary.Month.PercentLeft')
          month_history=$(${pkgs.jq}/bin/jq -c --arg at "$now" --argjson u "$month_used" \
            '.points = ((.points + [{at: $at, u: $u}]) | .[-2880:])' "$month_state") || exit 1
          echo "$month_history" > "$month_state"

          echo "$raw" | ${pkgs.jq}/bin/jq -cj --arg now "$now" --slurpfile state "$state" --slurpfile month_state "$month_state" '
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
             history: ($state[0].points | map({at: .at, u: (100 - .u)})),
             pace: pace_points(.Summary.Week.ResetsAt; 604800),
             month_history: ($month_state[0].points | map({at: .at, u: (100 - .u)})),
             month_pace: pace_points(.Summary.Month.ResetsAt; month_window_secs)}' | ${pkgs.jq}/bin/jq -Rs '{files: {"opencode-usage.json": {content: .}}}' | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${opencodeGistId}" --input - >/dev/null
        ''}";
      };
    };

    codex-usage-update = {
      description = "Publish Codex usage (agent001) to the widget Gist";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "codex-usage-update" ''
          set -u
          codex_home="$HOME/.agents/.codex.agent001"
          [ -s "$codex_home/auth.json" ] || exit 0

          raw=$(CODEX_HOME="$codex_home" ${llmQuota}/bin/llm-quota usage get-codex-usage 2>/dev/null) || exit 0
          usage=$(echo "$raw" | ${pkgs.jq}/bin/jq -c '
            (.Usage.RateLimit.PrimaryWindow // null) as $w
            | if $w == null then {} else
              {email: .Usage.Email, plan_type: .Usage.PlanType,
               weekly: {used_percent: $w.UsedPercent,
                        resets_at: ($w.ResetAt | strftime("%Y-%m-%dT%H:%M:%SZ")),
                        window_seconds: $w.LimitWindowSeconds}}
              end') || exit 0
          echo "$usage" | ${pkgs.jq}/bin/jq -e '.weekly' >/dev/null 2>&1 || exit 0

          state_dir="$HOME/.local/share/codex-usage"
          state="$state_dir/history.json"
          ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
          [ -s "$state" ] || echo '{"points":[]}' > "$state"

          now=$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
          used=$(echo "$usage" | ${pkgs.jq}/bin/jq -r '.weekly.used_percent')
          history=$(${pkgs.jq}/bin/jq -c --arg at "$now" --argjson u "$used" \
            '.points = ((.points + [{at: $at, u: $u}]) | .[-2880:])' "$state") || exit 1
          echo "$history" > "$state"

          echo "$usage" | ${pkgs.jq}/bin/jq -cj --arg now "$now" --slurpfile state "$state" '
            def pace_points:
              (.weekly.resets_at | fromdateiso8601) as $r
              | ($now | fromdateiso8601) as $n
              | (.weekly.window_seconds) as $secs
              | ($r - $secs) as $s
              | [range($s; ([$n, $r] | min); 900)
                 | {at: strftime("%Y-%m-%dT%H:%M:%SZ"),
                    u: ((1000 - ((. - $s) / $secs * 1000 | round)) / 10)}];
            {email, plan_type, weekly,
             updated_at: $now,
             history: ($state[0].points | map({at: .at, u: (100 - .u)})),
             pace: pace_points}' | ${pkgs.jq}/bin/jq -Rs '{files: {"codex-usage.json": {content: .}}}' | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${codexGistId}" --input - >/dev/null
        ''}";
      };
    };

    devin-usage-update = {
      description = "Publish Devin usage to the widget Gist";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "devin-usage-update" ''
          set -u
          cred="$HOME/.local/share/devin/credentials.toml"
          [ -s "$cred" ] || exit 0

          token=$(${pkgs.gnused}/bin/sed -n 's/^windsurf_api_key *= *"\(.*\)" *$/\1/p' "$cred" | ${pkgs.coreutils}/bin/head -n 1)
          [ -n "$token" ] || exit 0

          raw=$(${pkgs.curl}/bin/curl -s --max-time 30 -X POST \
            "https://server.codeium.com/exa.seat_management_pb.SeatManagementService/GetPlanStatus" \
            -H "x-auth-token: $token" \
            -H "Content-Type: application/json" \
            -H "Connect-Protocol-Version: 1" \
            --data '{}') || exit 0
          echo "$raw" | ${pkgs.jq}/bin/jq -e '.planStatus.planInfo.billingStrategy == "BILLING_STRATEGY_QUOTA"' >/dev/null 2>&1 || exit 0

          usage=$(echo "$raw" | ${pkgs.jq}/bin/jq -c '
            .planStatus as $s
            | def used($rem; $reset):
                if $rem != null then 100 - $rem
                elif $reset != null then 100
                else null end;
            def win($used; $reset; $secs):
                if $used == null then null else
                  {used_percent: $used,
                   resets_at: ($reset | tonumber | strftime("%Y-%m-%dT%H:%M:%SZ")),
                   window_seconds: $secs}
                end;
            {plan: $s.planInfo.planName,
             weekly: win(used($s.weeklyQuotaRemainingPercent; $s.weeklyQuotaResetAtUnix); $s.weeklyQuotaResetAtUnix; 604800),
             daily: win(used($s.dailyQuotaRemainingPercent; $s.dailyQuotaResetAtUnix); $s.dailyQuotaResetAtUnix; 86400),
             hide_daily_quota: ($s.planInfo.hideDailyQuota // false),
             overage_balance_usd: (if $s.overageBalanceMicros == null then null else ($s.overageBalanceMicros | tonumber) / 1000000 end),
             plan_start: $s.planStart, plan_end: $s.planEnd}') || exit 0
          echo "$usage" | ${pkgs.jq}/bin/jq -e '.weekly' >/dev/null 2>&1 || exit 0

          state_dir="$HOME/.local/share/devin-usage"
          state="$state_dir/history.json"
          ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
          [ -s "$state" ] || echo '{"points":[]}' > "$state"

          now=$(${pkgs.coreutils}/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
          used=$(echo "$usage" | ${pkgs.jq}/bin/jq -r '.weekly.used_percent')
          history=$(${pkgs.jq}/bin/jq -c --arg at "$now" --argjson u "$used" \
            '.points = ((.points + [{at: $at, u: $u}]) | .[-2880:])' "$state") || exit 1
          echo "$history" > "$state"

          echo "$usage" | ${pkgs.jq}/bin/jq -cj --arg now "$now" --slurpfile state "$state" '
            def pace_points:
              (.weekly.resets_at | fromdateiso8601) as $r
              | ($now | fromdateiso8601) as $n
              | (.weekly.window_seconds) as $secs
              | ($r - $secs) as $s
              | [range($s; ([$n, $r] | min); 900)
                 | {at: strftime("%Y-%m-%dT%H:%M:%SZ"),
                    u: ((1000 - ((. - $s) / $secs * 1000 | round)) / 10)}];
            {plan, weekly, daily, hide_daily_quota, overage_balance_usd, plan_start, plan_end,
             updated_at: $now,
             history: ($state[0].points | map({at: .at, u: (100 - .u)})),
             pace: pace_points}' | ${pkgs.jq}/bin/jq -Rs '{files: {"devin-usage.json": {content: .}}}' | ${pkgs.gh}/bin/gh api -X PATCH "/gists/${devinGistId}" --input - >/dev/null
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
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };

    codex-usage-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };

    devin-usage-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };
  };
}
