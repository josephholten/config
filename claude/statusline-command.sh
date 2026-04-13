#!/usr/bin/env bash
# Claude Code status line: model name + context usage + rate limits

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"')
ctx=$(echo "$input" | jq -r '.context_window.used_percentage // "??"')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // "??"')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // "??"')

printf '%s | ctx: %s%% | 5h: %s%% | 7d: %s%%' "$model" "$ctx" "$five" "$week"
