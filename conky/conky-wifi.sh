#!/usr/bin/env bash
# Wireless status for conky. Auto-detects the Wi-Fi interface (no name
# hardcoded) and prints "<essid>  <signal>%" with the IPv4 indented on a
# second line (aligned under the value column).
#
# Sources are deliberately non-scanning: `iw dev link` and nmcli's
# `dev show` query the *current* association only. (nmcli `dev wifi`
# is avoided -- it can block for seconds waiting on a rescan, which
# would freeze the whole conky panel.)
iface=""
for d in /sys/class/net/*; do
    [ -d "$d/wireless" ] || continue
    iface=$(basename "$d"); break
done
[ -z "$iface" ] && { echo "n/a"; exit 0; }
[ "$(cat "/sys/class/net/$iface/operstate" 2>/dev/null)" = up ] || { echo "down"; exit 0; }

link=$(timeout 2 iw dev "$iface" link 2>/dev/null)
essid=$(printf '%s\n' "$link" | sed -n 's/^\s*SSID: //p')
[ -z "$essid" ] && essid=$(timeout 2 nmcli -t -f GENERAL.CONNECTION dev show "$iface" 2>/dev/null | cut -d: -f2)
[ -z "$essid" ] && { echo "disconnected"; exit 0; }

# dBm -> percent (NetworkManager-style linear approx, clamped 0..100)
dbm=$(printf '%s\n' "$link" | sed -n 's/^\s*signal: \(-\?[0-9]*\).*/\1/p')
sig=""
if [ -n "$dbm" ]; then
    sig=$(( 2 * (dbm + 100) ))
    [ "$sig" -gt 100 ] && sig=100
    [ "$sig" -lt 0 ] && sig=0
fi

ip=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)

if [ -n "$sig" ]; then printf '%s  %s%%\n' "$essid" "$sig"; else printf '%s\n' "$essid"; fi
[ -n "$ip" ] && printf '     %s\n' "$ip"   # 5-space indent = width of "WIFI "
