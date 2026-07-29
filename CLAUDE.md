# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Joseph Holten's personal Linux dotfiles and config scripts, deployed by symlinking individual files/directories from `~/config/` into `~`, `~/.config/`, or system locations. `install.sh [desktop|laptop]` creates those symlinks (idempotent; it never overwrites a real file, it reports it instead) and ends by printing the steps it deliberately does not automate. See `linux.md` for the Arch Linux setup notes and per-tool READMEs (e.g. `git/README.md`, `pass/README.md`, `mail/README.md`) for how each piece is wired in.

Target system: Arch Linux + X11 + i3 + Emacs + st (suckless terminal). Some configs are host-specific (`desktop/`, `laptop/`, `phone/`, `tablet/`) — the same dotfile under different roots gets symlinked depending on the machine.

## Layout conventions

- Top-level files (`bashrc`, `vimrc`, `xinitrc`, `xprofile`, `Xresources`, `latexmkrc`) are symlinked into `$HOME` as dotfiles.
- Top-level directories named after a tool (`i3/`, `i3status/`, `git/`, `gnupg/`, `rofi/`, `zathura/`, `ssh/`, `matplotlib/`, `emacs/`, `claude/`, …) hold that tool's config and are symlinked into `~/.config/<tool>/` (or the tool's expected path).
- `mail/` holds the mbsync + notmuch configs only. Mail data, sync state and the notmuch index all live in `~/mail/`, which is outside this repo.
- `desktop/` and `laptop/` contain host-specific variants (currently `autorandr/` profiles and `restic/` backup profiles). Don't merge them — they intentionally diverge per machine.
- `phone/` and `tablet/` hold minimal `bashrc`/`vimrc` variants for Termux-style environments.
- `bash_defs.sh` is sourced from `bashrc`; put PATH exports, aliases, and shell functions there rather than in `bashrc` itself.
- Submodules: `st/` (Joseph's fork of suckless st), `rofi/rofi-power-menu`, `networkmanager-dmenu`. Use `git submodule update --init --recursive` after cloning.

## Building the small C utilities

Two custom X11 helpers ship as source and need to be compiled and installed into `~/bin` before `xprofile` can launch them:

```bash
make -C fullscreen_warning install   # builds fullscreen_warning, used by batsignal -D
make -C xsecurelock install    # builds saver_battery, used as XSECURELOCK_SAVER
make -C st install             # suckless st (submodule, edit config.h then rebuild)
```

Each Makefile uses `pkg-config` for X11/Xft/fontconfig flags and copies the binary to `$HOME/bin`. There is no global build — only touch the Makefile of the component you changed.

## Things that are non-obvious from the code

- **GPG agent doubles as ssh-agent**: `bashrc` sets `SSH_AUTH_SOCK` to gpg-agent's socket and runs `gpgconf --launch gpg-agent`. Do not add a separate ssh-agent. `KEYID=0x22C0152F739C743D` (in `bash_defs.sh`) is the key used by `gpgencrypt`/`gpgdecrypt`.
- **Git over SSH by default**: `git/config` rewrites `https://github.com/` → `git@github.com:` via `insteadOf`. Credentials for non-rewritten remotes go through `pass-git-helper` (see `pass/README.md`).
- **X session bootstrap lives in `xprofile`, not `i3/config`**: the i3 config explicitly notes autostarts were moved out. Add session-wide daemons (dunst, nm-applet, emacs --daemon, xss-lock, batsignal, etc.) to `xprofile`.
- **Screen lock chain**: `xss-lock` triggers `xsecurelock`, which uses the locally-built `saver_battery` as its saver module and `fullscreen_warning` (from `fullscreen_warning/`) as the low-battery alert. Breaking either C build breaks the lock screen UX. `fullscreen_warning` only closes on a deliberate key combo (`-k`, default `ctrl+shift+q`), not on any keystroke.
- **Ansible playbook is a stub**: `ansible/playbook.yaml` is a hello-world ping — there is no real automation yet. The README's "TODO: learn ansible" is still accurate; don't assume Ansible is the deployment path.
- **`pass-git-helper` path**: `git/config` references `/sbin/pass-git-helper`. On a fresh machine this needs `yay -S pass-git-helper` and the config symlink from `pass/README.md`.
- **Mail is deliberately hobbled until proven**: `mail/mbsyncrc` ends with a `--- first-test bounds ---` block (`Sync Pull`, `Patterns "INBOX"`, `MaxMessages 200`, `ExpireUnread yes`). `Sync Pull` makes the sync one-way so a misconfiguration can't damage the server. mbsync has **no date filter** — message count is the only bound it offers. Delete the whole block to go live. Separately, `new.ignore` in `mail/notmuch-config` is required, not cosmetic: mbsync keeps state files inside the maildir (`SyncState *`) and notmuch errors on them otherwise. isync ≥1.4 uses `Far`/`Near` and `TLSType`, not the `Master`/`Slave`/`SSLType` of older tutorials. In `mbsyncrc` a **blank line ends a section**, so keep each block contiguous (comments inside are fine) — otherwise options get parsed as global keywords. `mbsync -l nosuchchannel` parse-checks the file without any network or gpg access.
- **Restic profiles run as system schedules**: `desktop/restic/profiles.yaml` and `laptop/restic/profiles.yaml` install systemd timers via `resticprofile schedule`. The `run-before`/`run-after` hooks do `sudo -u joseph … notify-send` to surface backup status in the user session — keep `DISPLAY=:0` and `DBUS_SESSION_BUS_ADDRESS` set when editing.

## Useful commands defined here

These come from `bash_defs.sh` and are worth knowing when reading scripts in this repo:

- `wgup` / `wgdown` — bring `wg0` WireGuard up/down.
- `wakeserver` — WoL the home server via `joseph-pi`.
- `gpgencrypt FILE` / `gpgdecrypt FILE.<ts>.enc` — symmetric-style helpers around `gpg` using `$KEYID`.
- `of [DIR]` / `vf [DIR]` — fzf-pick a file under DIR and `xdg-open` / `vim` it.
- `probe_mathcluster.sh` — SSH-loops the `pde01..pde22` nodes to print CPU/mem.
- `wireguard/wg-genclient.sh` — must run as root; provisions a new peer in `jvpn.conf`, appends `[Peer]` block, reloads `wg-quick@jvpn`, prints a QR code.
