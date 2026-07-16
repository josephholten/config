#!/usr/bin/env bash
# Launch one conky instance per monitor, each pinned to its Xinerama head,
# so the mod-hold system-info panel shows up on every screen.
#
# Re-runnable and idempotent: it kills any existing instances first. Used
# both at session start (xprofile) and as an autorandr postswitch hook
# (see ~/.config/autorandr/postswitch.d/10-conky) so the set of panels
# tracks the current monitor layout after docking/undocking.
#
# Any arguments/env autorandr passes to the hook are ignored.
set -u

CONF="$HOME/.config/conky/conky.conf"

# Stop any running instances, then wait for them to release their windows.
pkill -x conky 2>/dev/null
for _ in $(seq 1 20); do
    pgrep -x conky >/dev/null 2>&1 || break
    sleep 0.05
done

# One conky per monitor, pinned to that Xinerama head. The leading index
# in `xrandr --listmonitors` is 0-based and matches conky's xinerama_head
# numbering. Fall back to a single primary-head instance if parsing fails.
heads=$(xrandr --listmonitors 2>/dev/null \
        | sed -n 's/^[[:space:]]*\([0-9][0-9]*\):.*/\1/p')
[ -n "$heads" ] || heads=0

for h in $heads; do
    CONKY_HEAD="$h" conky -d -c "$CONF"
done

# Start hidden: unmap the freshly-created windows so they only appear
# while Super is held. conky-mod-toggle.sh maps/unmaps them from there on.
for _ in $(seq 1 50); do
    wins=$(xdotool search --class Conky 2>/dev/null)
    if [ -n "$wins" ]; then
        for w in $wins; do xdotool windowunmap "$w"; done
        break
    fi
    sleep 0.1
done
