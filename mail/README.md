# mail — terminal-first email: mbsync → ~/mail → notmuch

Three independent pieces, no daemon and no mail client:

```
IMAP server ──mbsync──► ~/mail/holten/{INBOX,…}   Maildir
                              │
                        notmuch new
                              │
                      ~/mail/.notmuch/            Xapian index
                              │
                      $ notmuch search …
```

Configs live here and are symlinked out by `install.sh`. **All mail data and
sync state lives under `~/mail/`, which is not part of this repo** — nothing
here needs a `.gitignore` entry.

Sending mail (msmtp), a TUI (aerc/neomutt) and Emacs integration are
deliberately not set up yet. See "Next steps".

## Install

```bash
sudo pacman -S isync notmuch
pass insert mail/holten          # the IMAP password
mkdir -p ~/mail/holten
~/config/install.sh              # links mbsyncrc + notmuch-config
```

Then fill in `Host` and `User` in `mbsyncrc` — they're marked `FILL IN`.

Note that `pass insert` writes `pass/password-store/mail/holten.gpg` **into
this repo**, tracked, as an encrypted blob. That is the existing pattern here
(see the overleaf and zenodo entries), but it is worth knowing.

## First run — do these in order and stop at the first failure

Each step isolates one failure mode, so a failure tells you what broke.

```bash
# 1. credential works standalone (Yubikey must be plugged in; PIN once per session)
pass mail/holten

# 2. THE key test: lists remote folders, transfers no mail.
#    Proves DNS + TLS + PassCmd + login all at once.
mbsync -l holten

# 3. bounded fetch, verbose
mbsync -V holten

# 4. mail actually landed
ls ~/mail/holten/INBOX/cur | wc -l     # expect <= ~200

# 5. index it
notmuch new                            # expect "Added N messages", no errors

# 6. search
notmuch count
notmuch search date:2d..               # the last 48h
notmuch search from:someone
notmuch show thread:000000000000abcd | less
```

Step 2 is the one that matters. It separates an auth/TLS problem from a
maildir/permissions problem, which a plain `mbsync` run does not.

If step 2 fails:

| symptom | cause |
|---|---|
| `pass mail/holten` prints nothing | Yubikey not plugged in, or gpg-agent has no pinentry (`export GPG_TTY=$(tty)`) |
| host unreachable / timeout | wrong `Host` or `Port` |
| certificate error | wrong `CertificateFile`; for a private CA point it at that single PEM. For a STARTTLS-only server use `Port 143` + `TLSType STARTTLS` |
| `AUTHENTICATE` rejected | `User` form — try the bare login instead of the full address, or the server wants an app password |
| unknown keyword `Master`/`SSLType` | you copied a pre-1.4 tutorial; this file uses `Far`/`Near` and `TLSType` |

## Live delivery (IMAP IDLE)

mbsync has **no IDLE support** — on its own it can only ever poll. So a small
daemon holds the idle connection and pokes mbsync when something lands:

```
goimapnotify ──IDLE on INBOX──► mail/on-new-mail.sh
                                  ├─ mbsync holten   (ALL folders)
                                  ├─ notmuch new
                                  └─ notify-send     (dunst)
```

**INBOX is only the trigger, not the scope.** `on-new-mail.sh` runs a plain
`mbsync holten`, so Archives, Sent, Invoices and the rest all sync too — what
gets synced is decided by `Patterns` in `mbsyncrc`, never by the caller.
Watching INBOX alone keeps this to *one* IMAP connection; omitting `boxes`
would open one IDLE connection per folder (~18), which hosts often refuse.

Three user units, all symlinked by `install.sh`:

| unit | |
|---|---|
| `goimapnotify.service` | the IDLE daemon, `Restart=always` |
| `mbsync.service` | oneshot, runs the same handler |
| `mbsync.timer` | fires it every 30 min as a backstop |

`Restart=always` is doing real work: `passwordCMD` goes through `pass` →
gpg-agent → Yubikey, and at session start the card usually isn't unlocked yet,
so the first attempts fail. Without supervision the daemon would die at login
and mail would silently stop.

The timer exists because an IDLE connection can drop silently — suspend, NAT
timeout, server-side reset. 30 min is deliberately slow; it's a safety net,
not the primary path.

```bash
systemctl --user status goimapnotify        # is it connected?
journalctl --user -u goimapnotify -f        # watch it react
systemctl --user list-timers mbsync.timer   # when does the backstop fire?
systemctl --user start mbsync.service       # force a sync now
```

`Environment=DISPLAY=:0` is for **pinentry**, so the Yubikey PIN prompt has
somewhere to draw. `notify-send` doesn't need it — libnotify talks to the
session bus, which `systemd --user` already provides.

## Reading mail in Emacs

`emacs/init.el` has a `notmuch` block under the `SPC m` leader:

| key | |
|---|---|
| `SPC m m` | notmuch hello screen (saved searches) |
| `SPC m s` | `notmuch-search` |
| `SPC m c` | compose |
| `SPC m u` | re-run `notmuch new` and refresh |

`SPC m u` only re-indexes; it does **not** fetch. Run `mbsync holten` first (or
wait for the timer, once that exists).

It uses `:ensure nil` on purpose. Arch's `notmuch` package installs the elisp
into `/usr/share/emacs/site-lisp`, which is already on the load-path, and that
guarantees notmuch-emacs matches the notmuch CLI version. Taking it from MELPA
instead invites version skew between the two, which breaks in confusing ways.

## Sending

`mail/msmtprc` → `~/.msmtprc`, reading the *same* `pass mail/holten` entry as
mbsync. Emacs sends through it via `message-send-mail-with-sendmail`; sent mail
is filed into `~/mail/holten/Sent` by `notmuch-fcc-dirs`, and the next `mbsync`
pushes it to the server.

No password is stored in `msmtprc` (it uses `passwordeval`), which is why the
file can be world-readable in the repo. Inline a literal `password` line and
msmtp will refuse to run unless the file is `chmod 600`.

Verify the host/port against one.com's current docs, then:

```bash
echo "test body" | msmtp --debug --from=default -t you@somewhere-else.com
```

## Widening, once the above works

Already done — `Patterns` now takes all folders except trash/spam, and the
one-way `Sync Pull` / `MaxMessages` bounds are gone. Kept for reference:

- mbsync has **no date filter**. Message count (`MaxMessages`) is the only
  bound it offers, which is why "last 48h" was originally approximated as
  "newest 200". Expiry is reversible: raising or dropping the cap re-fetches.
- `ExpireUnread yes` is required alongside `MaxMessages`, since the default
  exempts unread mail from the cap entirely.
- `Expunge` is left at its default `None`, so deleting mail locally flags it
  rather than removing it from the server.

To round-trip read/unread state to the server, set `synchronize_flags=true`
in `notmuch-config`.

Listing remote folders respects `Patterns`, so `mbsync -l` won't show folders
you've excluded. To see everything the server actually has:

```bash
sed 's|^Patterns .*|Patterns "*"|' ~/.mbsyncrc > /tmp/probe.rc
mbsync -c /tmp/probe.rc -l holten
```

## Gotchas

- **A blank line ends a section in `mbsyncrc`.** Options after one are parsed
  as global keywords, giving errors like `'Patterns' is not a recognized
  section-starting or global keyword`. Comment lines are fine inside a
  section; empty ones are not. Keep each `IMAPAccount` / `MaildirStore` /
  `Channel` block contiguous.
- **isync >= 1.4 renamed everything.** `Master`/`Slave` → `Far`/`Near`,
  `SSLType` → `TLSType`. Arch ships 1.5.x. Most blog posts predate this.
- **Check the config parses without hitting the network**: `mbsync -l
  nosuchchannel`. It reads the whole file, then errors only about the unknown
  channel — any real parse error shows up first, with a line number.
- **`notmuch config set` and `notmuch setup` rewrite the config file** and can
  replace the symlink with a regular file. Edit `notmuch-config` by hand; if a
  command does clobber it, re-run `install.sh`.
- **`new.ignore` is not optional.** mbsync keeps its state files inside the
  maildir (`SyncState *`), and notmuch will try to index them and error on
  every run without the ignore list.
- **The notmuch database path is `~/mail`, one level above `~/mail/holten`**,
  so a second account can be added later and share the index.
- **Rebuilding the index is free and safe**: `rm -rf ~/mail/.notmuch &&
  notmuch new`. It never touches the mail itself.

## Next steps

1. Automatic sync — a `mbsync.service` + `mbsync.timer` user unit. These would
   be the repo's first checked-in systemd units, so `install.sh` needs a new
   `systemctl --user enable` section. gpg-agent runs `--supervised` under
   systemd so a timer does reach it; the failure mode is just "Yubikey
   unplugged" → unit fails, retries later. Alternative precedent: a
   NetworkManager dispatcher script, like `tz/09-timezone`.
2. Sending — `msmtp`, reading the same `pass mail/holten` entry.
3. A TUI — `aerc` or `neomutt`, both have notmuch backends.
4. Emacs — `notmuch` is on MELPA, so `(use-package notmuch)` in
   `emacs/init.el`, plus adding `notmuch` to the `evil-collection-init`
   allowlist and an `SPC m` leader binding.
