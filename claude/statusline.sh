#!/bin/sh
# Claude Code status line + rate-limit logger (POSIX sh + jq).
# Appends one JSONL record when the rounded percentages change; concurrent
# TUIs race benignly (single O_APPEND printf, dupes removed by quota-report.sh).

LOG="$HOME/.claude/quota-log.jsonl"

input=$(cat)

IFS='	' read -r model_id model_name sess_pct sess_reset week_pct week_reset ctx <<EOF
$(printf '%s' "$input" | jq -r '
  def pct: if type=="number" then .+0.5|floor|tostring else "?" end;
  [ (.model.id // "?"),
    (.model.display_name // .model.id // "Claude"),
    (.rate_limits.five_hour.used_percentage? | pct),
    ((.rate_limits.five_hour.resets_at? // 0) | tostring),
    (.rate_limits.seven_day.used_percentage? | pct),
    ((.rate_limits.seven_day.resets_at? // 0) | tostring),
    (.context_window.used_percentage? | pct)
  ] | @tsv' 2>/dev/null)
EOF

: "${model_id:=?}" "${model_name:=Claude}" "${sess_pct:=?}" "${sess_reset:=0}" \
  "${week_pct:=?}" "${week_reset:=0}" "${ctx:=?}"

case "$sess_pct$week_pct" in
  *[!0-9]*) ;;  # rate_limits missing/malformed: show "?" but log nothing
  *)
    last=$(tail -n 1 "$LOG" 2>/dev/null | jq -r '"\(.sess_pct) \(.week_pct)"' 2>/dev/null)
    if [ "$last" != "$sess_pct $week_pct" ]; then
      printf '{"ts":"%s","sess_pct":%s,"sess_reset":%s,"week_pct":%s,"week_reset":%s,"model_id":"%s","model_name":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$sess_pct" "$sess_reset" "$week_pct" "$week_reset" \
        "$model_id" "$model_name" >> "$LOG"
    fi
    ;;
esac

# display: used% / share of the rate-limit window already elapsed
now=$(date +%s)
time_pct() {  # $1 = resets_at epoch, $2 = window length in seconds
  [ "$1" -gt 0 ] 2>/dev/null || { echo "?"; return; }
  e=$(( $2 - ($1 - now) ))
  [ "$e" -lt 0 ] && e=0
  [ "$e" -gt "$2" ] && e=$2
  echo $(( (e * 100 + $2 / 2) / $2 ))
}

printf '%s | ctx: %s%% | 5h: %s/%s%% | 7d: %s/%s%%' \
  "$model_name" "$ctx" \
  "$sess_pct" "$(time_pct "$sess_reset" 18000)" \
  "$week_pct" "$(time_pct "$week_reset" 604800)"
