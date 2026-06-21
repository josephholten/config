#!/usr/bin/env bash
# Battery status for conky, short form: "<pct>%  <sign><H:MM>".
# sign = '+' charging, '-' discharging, ' ' otherwise (full/idle).
# Auto-detects the first battery (no BAT0 hardcoded); prints "AC" when no
# battery is present. Time-to-empty/full from energy+power or charge+current.
bat=""
for d in /sys/class/power_supply/*; do
    [ "$(cat "$d/type" 2>/dev/null)" = Battery ] || continue
    bat="$d"; break
done
[ -z "$bat" ] && { echo "AC"; exit 0; }

cap=$(cat "$bat/capacity" 2>/dev/null)
status=$(cat "$bat/status" 2>/dev/null)
case "$status" in
    Charging)    sign='+' ;;
    Discharging) sign='-' ;;
    *)           sign=' ' ;;
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

if [ -n "$t" ]; then printf '%s%%  %s%s\n' "$cap" "$sign" "$t"; else printf '%s%%\n' "$cap"; fi
