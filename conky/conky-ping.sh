#!/usr/bin/env bash
# Actual internet connectivity for conky: prints "<host>  <rtt> ms" on
# success, or "offline" when unreachable. This proves end-to-end reachability,
# unlike WLN/ETH which only report a link/IP -- you can be "up" on the LAN yet
# have no route to the internet.
#
# To keep traffic down we send ICMP *only when the network changes*. Each call
# fingerprints the connectivity-relevant state (default route + global IPv4s);
# while that is unchanged we replay the cached result with no new packets, so
# in steady state this script reads two cheap `ip` tables and pings nothing.
# A real probe fires only when you connect/disconnect/switch networks or get a
# new lease. Tradeoff: an upstream/ISP outage that leaves your local route
# intact won't be re-detected until the next network change.
host=google.com
cache="${XDG_RUNTIME_DIR:-/tmp}/conky-ping"
state="$cache.state"
result="$cache.result"

# Fingerprint of connectivity-relevant network state.
fp=$(ip route show default 2>/dev/null; ip -o -4 addr show scope global 2>/dev/null | awk '{print $2, $4}')

# Unchanged since last probe -> replay cached result, send nothing.
if [ -f "$state" ] && [ -f "$result" ] && [ "$fp" = "$(cat "$state")" ]; then
    cat "$result"
    exit 0
fi

# Network changed (or first run): probe once, cache the verdict + fingerprint.
if out=$(ping -n -c1 -w2 "$host" 2>/dev/null); then
    rtt=$(printf '%s\n' "$out" | sed -n 's/.*time=\([0-9.]*\).*/\1/p' | head -n1)
    if [ -n "$rtt" ]; then
        printf '%s  %.0f ms\n' "$host" "$rtt" > "$result"
    else
        printf '%s  ok\n' "$host" > "$result"
    fi
else
    printf 'offline\n' > "$result"
fi
printf '%s' "$fp" > "$state"
cat "$result"
