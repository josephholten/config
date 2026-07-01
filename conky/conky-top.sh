#!/usr/bin/env bash
# Top processes by instantaneous CPU (htop-style), count = nproc.
# Caches per-pid CPU jiffies between calls so no sampling sleep is needed;
# %CPU is per-core (a fully-busy single thread reads ~100%).
# Per Xinerama head, so multiple conky instances (one per monitor, see
# conky-launch.sh) don't corrupt each other's cached jiffies/deltas.
STATE="${TMPDIR:-/tmp}/conky-top.$(id -u).${CONKY_HEAD:-0}"
ncpu=$(nproc)
N=$ncpu

read -r _ u n s i io ir so st _ < /proc/stat
now_total=$((u+n+s+i+io+ir+so+st))
prev_total=0
[ -f "$STATE.total" ] && read -r prev_total < "$STATE.total"
echo "$now_total" > "$STATE.total"
dtotal=$((now_total - prev_total)); [ "$dtotal" -le 0 ] && dtotal=1

declare -A prev
if [ -f "$STATE" ]; then
    while read -r pid j; do prev[$pid]=$j; done < "$STATE"
fi

: > "$STATE"
{
for d in /proc/[0-9]*; do
    pid=${d#/proc/}
    { read -r line < "$d/stat"; } 2>/dev/null || continue
    comm=${line#*(}; comm=${comm%)*}        # name between first ( and last )
    after=${line##*) }                      # fields after comm: state is $1
    set -- $after
    j=$(( ${12} + ${13} ))                  # utime + stime
    printf '%s %s\n' "$pid" "$j" >> "$STATE"
    p=${prev[$pid]:-$j}
    delta=$((j - p)); [ "$delta" -le 0 ] && continue
    pct=$(( 100 * ncpu * delta / dtotal ))
    printf '%d\t%s\n' "$pct" "$comm"
done
} | sort -rn | awk -F'\t' '$1 > 10' | head -n "$N" | while IFS=$'\t' read -r pct comm; do
    printf '%-16.16s %3d%%\n' "$comm" "$pct"
done
