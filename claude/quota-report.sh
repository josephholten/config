#!/bin/sh
# Monthly quota report over ~/.claude/quota-log.jsonl (written by statusline.sh).
# Loads the log into a temp sqlite db; duplicate rows from concurrent TUIs
# are expected and dropped via SELECT DISTINCT.

LOG="${1:-$HOME/.claude/quota-log.jsonl}"
[ -s "$LOG" ] || { echo "no data in $LOG" >&2; exit 1; }

db=$(mktemp) || exit 1
trap 'rm -f "$db"' EXIT

jq -r '[.ts,.sess_pct,.sess_reset,.week_pct,.week_reset,.model_id] | @csv' "$LOG" |
sqlite3 "$db" \
  "CREATE TABLE raw(ts TEXT, sess_pct INT, sess_reset INT, week_pct INT, week_reset INT, model_id TEXT);" \
  ".mode csv" \
  ".import /dev/stdin raw"

sqlite3 "$db" <<'SQL'
CREATE TABLE q AS SELECT DISTINCT * FROM raw;
.mode column
.headers on
.print === Weekly peak usage (primary metric) ===
SELECT datetime(week_reset,'unixepoch') AS week_resets_utc,
       MAX(week_pct) AS peak_pct,
       COUNT(*) AS samples
FROM q GROUP BY week_reset ORDER BY week_reset;
.print
.print === Session (5h) window peaks ===
SELECT datetime(sess_reset,'unixepoch') AS sess_resets_utc,
       MAX(sess_pct) AS peak_pct
FROM q GROUP BY sess_reset ORDER BY sess_reset;
.print
SELECT COUNT(*) AS session_windows_over_90pct
FROM (SELECT 1 FROM q GROUP BY sess_reset HAVING MAX(sess_pct) > 90);
.print
.print === Samples per model ===
SELECT model_id, COUNT(*) AS n,
       printf('%.1f%%', 100.0*COUNT(*)/(SELECT COUNT(*) FROM q)) AS share
FROM q GROUP BY model_id ORDER BY n DESC;
SQL
