#!/usr/bin/env bash
# Battery status for conky. Two modes (so conky can place them in
# separate columns -- percent left, time right-aligned):
#   conky-bat.sh pct   -> "<pct>%"  right-padded to 3 digits (e.g. " 42%")
#   conky-bat.sh time  -> "<arrow> <H:MM>"  arrow = down discharging,
#                         up charging, blank otherwise; empty if no estimate
# Auto-detects the first battery (no BAT0 hardcoded). "AC" / "" when none.
mode="${1:-pct}"

bat=""
for d in /sys/class/power_supply/*; do
    [ "$(cat "$d/type" 2>/dev/null)" = Battery ] || continue
    bat="$d"; break
done
if [ -z "$bat" ]; then
    [ "$mode" = pct ] && echo "AC"
    exit 0
fi

cap=$(cat "$bat/capacity" 2>/dev/null)
status=$(cat "$bat/status" 2>/dev/null)

if [ "$mode" = pct ]; then
    printf '%3d%%\n' "$cap"
    exit 0
fi

# time mode
case "$status" in
    Charging)    arrow=$'↑' ;;   # up: filling
    Discharging) arrow=$'↓' ;;   # down: draining
    *)           arrow=' ' ;;
esac

# energy (uWh) + power (uW), else charge (uAh) + current (uA)
now=$(cat "$bat/energy_now" 2>/dev/null); full=$(cat "$bat/energy_full" 2>/dev/null); rate=$(cat "$bat/power_now" 2>/dev/null)
if [ -z "$rate" ]; then
    now=$(cat "$bat/charge_now" 2>/dev/null); full=$(cat "$bat/charge_full" 2>/dev/null); rate=$(cat "$bat/current_now" 2>/dev/null)
fi

t=""
if [ -n "$rate" ] && [ "$rate" -gt 0 ] 2>/dev/null; then
    case "$status" in
        Discharging) rem=$now ;;
        Charging)    rem=$((full - now)) ;;
        *)           rem="" ;;
    esac
    if [ -n "$rem" ] && [ "$rem" -gt 0 ]; then
        tm=$(( rem * 60 / rate ))           # minutes
        t=$(printf '%d:%02d' $((tm/60)) $((tm%60)))
    fi
fi

[ -n "$t" ] && printf '%s %s\n' "$arrow" "$t"
