#!/usr/bin/env bash
# Show the conky window only while a Super (Mod4) key is held down,
# mirroring i3bar's `mode hide` + `modifier $mod` behaviour.
#
# It *reads* raw XInput2 key events rather than grabbing Super, so every
# existing Mod4+<key> i3 binding keeps working. The conky window is an
# override-redirect window (own_window_type = override), so i3 ignores
# it and we just map/unmap it with xdotool.
#
# The panel only appears after Super has been held for $DELAY seconds, so
# quick Super+<key> chords don't flash it. On press we arm a background
# timer; releasing before it fires kills it, so the window never maps.

set -u

# Super_L / Super_R keycodes -- see: xmodmap -pke | grep Super_
SUPER_L=133
SUPER_R=134

DELAY=0.3   # seconds Super must be held before the panel shows

find_win() { xdotool search --class Conky 2>/dev/null | head -n1; }

# Start hidden once conky's window exists.
for _ in $(seq 1 50); do
    win=$(find_win)
    [ -n "$win" ] && { xdotool windowunmap "$win"; break; }
    sleep 0.1
done

ev=""
held=0
timer=""
xinput test-xi2 --root 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *RawKeyPress*)   ev=press   ;;
        *RawKeyRelease*) ev=release ;;
        *"detail:"*)
            code=${line##*detail: }
            [ "$code" = "$SUPER_L" ] || [ "$code" = "$SUPER_R" ] || continue
            win=$(find_win)
            [ -n "$win" ] || continue
            if [ "$ev" = press ] && [ "$held" -eq 0 ]; then
                held=1
                # arm timer: map only if still held after $DELAY
                ( sleep "$DELAY"; xdotool windowmap "$win"; xdotool windowraise "$win" ) &
                timer=$!
            elif [ "$ev" = release ] && [ "$held" -eq 1 ]; then
                held=0
                [ -n "$timer" ] && kill "$timer" 2>/dev/null   # cancel if not yet fired
                timer=""
                xdotool windowunmap "$win"
            fi
            ;;
    esac
done
