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

## Widening, once the above works

`mbsyncrc` starts deliberately hobbled. Delete the `--- first-test bounds ---`
block at the end of the file, which drops:

- `Sync Pull` → back to the default two-way sync, so local flag/move changes
  reach the server
- `Patterns "INBOX"` → all folders
- `MaxMessages 200` / `ExpireUnread yes` → the whole mailbox. mbsync has **no
  date filter**; message count is the only bound it offers, which is why "last
  48h" was approximated as "newest 200". Removing the cap re-fetches whatever
  was expired, so this is reversible.

Then:

```bash
mbsync -V holten && notmuch new
```

If you also want read/unread state to round-trip, set
`synchronize_flags=true` in `notmuch-config` — but only after `Sync Pull` is
gone, otherwise the flags never leave the machine.

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
