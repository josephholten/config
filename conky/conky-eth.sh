#!/usr/bin/env bash
# Print the active wired (non-wireless) interface and its IPv4, for conky.
# Falls back to "down" when no wired interface is up. Auto-detects the
# name, so it works across machines without hardcoding enpXsY/eth0.
for d in /sys/class/net/*; do
    n=$(basename "$d")
    [ "$n" = lo ] && continue
    [ -d "$d/wireless" ] && continue                       # skip wifi
    [ "$(cat "$d/operstate" 2>/dev/null)" = up ] || continue
    ip=$(ip -4 -o addr show dev "$n" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
    printf '%s  %s\n' "$n" "${ip:-no ip}"
    exit 0
done
echo "down"
