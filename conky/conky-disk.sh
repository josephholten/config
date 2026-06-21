#!/usr/bin/env bash
# Root-fs usage for conky: "<pct>  <used> / <size>", formatted so the "/"
# lines up with the RAM row (same printf widths as conky-mem.sh).
read -r used size pct < <(df -h --output=used,size,pcent / | tail -n1)
printf '%3d%%  %8s / %s\n' "${pct%\%}" "$used" "$size"
