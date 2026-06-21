#!/usr/bin/env bash
# RAM usage for conky: "<pct>%  <used> / <total>", formatted so the "/"
# lines up with the disk row (same printf widths as conky-disk.sh).
read -r tot_h used_h < <(free -h | awk '/^Mem:/{print $2, $3}')
read -r tot used     < <(free -m | awk '/^Mem:/{print $2, $3}')
pct=0; [ "${tot:-0}" -gt 0 ] && pct=$(( used * 100 / tot ))
printf '%3d%%  %8s / %s\n' "$pct" "$used_h" "$tot_h"
