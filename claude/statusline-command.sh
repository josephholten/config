#!/usr/bin/env bash
# Claude Code status line: model name + context usage + rate limits

input=$(cat)

vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"')

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

if [ -n "$vim_mode" ]; then
  parts="[$vim_mode] $model"
else
  parts="$model"
fi

if [ -n "$used" ]; then
  parts="$parts | ctx: $(printf '%.0f' "$used")% used"
fi

rate_parts=""
if [ -n "$five" ]; then
  rate_parts="5h: $(printf '%.0f' "$five")%"
fi
if [ -n "$week" ]; then
  [ -n "$rate_parts" ] && rate_parts="$rate_parts  7d: $(printf '%.0f' "$week")%" || rate_parts="7d: $(printf '%.0f' "$week")%"
fi
if [ -n "$rate_parts" ]; then
  parts="$parts | $rate_parts"
fi

printf '%s' "$parts"
