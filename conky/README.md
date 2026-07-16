# conky — mod-hold system-info panel

A stacked system-info panel (clock, wifi/eth/net/battery, ram/disk, per-core
CPU, top processes) shown **only while Super (Mod4) is held**, mirroring
i3bar's `mode hide` + `modifier $mod`. The window is `own_window_type =
override` so i3 ignores it; `conky-mod-toggle.sh` reads raw XInput2 key events
and maps/unmaps the windows with xdotool.

## Multi-monitor

One conky instance runs **per monitor**, each pinned to its Xinerama head, so
the panel appears on every screen. Without pinning, conky's `alignment` is
relative to the *combined* X screen, so with two monitors (especially with a
vertical offset between them) the panel lands in dead space / the middle of a
screen.

- `conky.conf` reads `$CONKY_HEAD` for its `xinerama_head`; with no env set it
  falls back to auto-detecting the primary monitor from `xrandr --listmonitors`.
- `conky-launch.sh` enumerates every head from `xrandr --listmonitors` and
  starts one `CONKY_HEAD=<n> conky …` per head, then unmaps them so they start
  hidden. It is idempotent (kills existing instances first).
- `conky-mod-toggle.sh` maps/unmaps **all** Conky windows at once.

## Wiring (fresh machine)

`xprofile` runs `conky-launch.sh` at session start, plus `conky-mod-toggle.sh &`.

To keep the panels tracking the monitor layout after docking/undocking, wire
the launcher into autorandr as a global postswitch hook (this symlink lives
under `~/.config/autorandr`, which is not part of this repo, so recreate it
per machine):

```bash
mkdir -p ~/.config/autorandr/postswitch.d
ln -sfn ~/.config/conky/conky-launch.sh ~/.config/autorandr/postswitch.d/10-conky
```

Note: the head is chosen when each conky starts, so a layout change requires
re-running `conky-launch.sh` — which the autorandr hook does automatically.
