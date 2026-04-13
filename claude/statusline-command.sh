#!/usr/bin/env bash
# Claude Code status line: model name + context usage + rate limits

now=$(date +%s)

_time_pct() {
  local resets_at=$1 duration=$2
  [ -z "$resets_at" ] && return
  local resets remaining elapsed
  resets=$(date -d "$resets_at" +%s 2>/dev/null) || return
  remaining=$(( resets - now ))
  elapsed=$(( duration - remaining ))
  printf '%.0f' "$(echo "scale=2; $elapsed * 100 / $duration" | bc)"
}

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // "??"')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // "??"')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // "??"')

fres=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
wres=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

printf '%s | ctx: %s%% | 5h: %s%% | 7d: %s%%' "$model" "$ctx" "$five" "$week"
