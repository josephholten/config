# mail — terminal-first email: mbsync → /var/lib/mail → notmuch

Three independent pieces, no mail client — split across **two Unix users**,
which is the first thing to understand here:

```
        ─── as mailsync ────────────────────────────────────────
one.com ──mbsync holten──► /var/lib/mail/holten/{INBOX,…}  Maildir
KIT     ──mbsync kit─────► /var/lib/mail/kit/{INBOX,…}     Maildir
                              │  stamp file
        ─── as joseph ─────────┼────────────────────────────────
                        notmuch new
                              │
                  ~/.local/state/notmuch/     ONE Xapian index
                              │
                      $ notmuch search …
```

Two accounts, one index. That is the whole reason `database.mail_root` is
`/var/lib/mail` and not `/var/lib/mail/holten`: searches, threads and tags span
both accounts, and `notmuch search from:x` doesn't care which server the mail
came from. The accounts stay separate only where they must — credentials, Sent
folder, and which server a reply goes out through.

**Mail data lives under `/var/lib/mail`, not in this repo and not in `$HOME`.**
`~/mail` is a symlink to it for convenience. Nothing here needs a `.gitignore`
entry.

Only the joseph-side configs are symlinked out by `install.sh`
(`notmuch-config`, `msmtprc`, `mail-index.*`). Everything under `mailsync/`
is deployed with `sudo` — see "Deploying the mailsync side".

## Why two users

The IMAP password is also the account password: one.com and KIT offer no
app-specific credential, so leaking it means account takeover, not just mail
access. Anything running as joseph — a compromised dependency, a shell script,
an AI agent with a terminal — can read any file joseph can read. So the
credential does not live anywhere joseph can reach:

| | owner | mode | joseph |
|---|---|---|---|
| `/var/lib/mailsync/creds/{holten,kit}` | `mailsync:mailsync` | `0600` | **cannot read** |
| `/var/lib/mailsync/{mbsyncrc,goimapnotify.yaml}` | `mailsync:mailsync` | `0640` | cannot read |
| `/var/lib/mailsync/pub/last-sync` | `mailsync:mail-ro` | `0640` | reads |
| `/var/lib/mail/**` | `mailsync:mail-ro` | `2750` / `0640` | reads only |

Joseph is in `mail-ro`; `mailsync` is not a group joseph belongs to. Read-only
on the maildir is enough because `synchronize_flags=false` — notmuch never
renames a file, and `rename(2)` is the only write mail indexing would need.

The credential is stored **twice**: this `0600` copy for unattended fetching,
and the `pass` entry for interactive sending via msmtp. Same secret, two
protections matched to two usage patterns — a background sync cannot wait for a
Yubikey touch, and an interactive send can.

Sending (msmtp) still runs as joseph out of `pass`, deliberately. See "Sending".

## Install

```bash
sudo pacman -S isync notmuch goimapnotify
pass insert mail/holten          # the IMAP password
pass insert kit                  # KIT — top-level entry, not mail/kit
~/config/install.sh              # links notmuch-config, msmtprc, mail-index.*
```

Then the `mailsync` side, below — the maildir is created by that, not by
`mkdir` in `$HOME`.

The two accounts name their credentials inconsistently — `pass mail/holten`
but `pass kit`. That is the existing store layout, not a typo; `passwordeval`
in `msmtprc` and the credential **filenames** under
`/var/lib/mailsync/creds/` must match it.

## Deploying the mailsync side

One-time, needs `sudo`. The credential copies are the only step that must be
done by hand — deliberately, since the whole design rests on nothing automated
ever handling them.

```bash
# 1. user, group, directories
sudo groupadd -r mail-ro
sudo useradd -r -m -d /var/lib/mailsync -s /usr/bin/nologin mailsync
sudo usermod -aG mail-ro mailsync
sudo usermod -aG mail-ro joseph                 # log out and back in after this
sudo chgrp mail-ro /var/lib/mailsync && sudo chmod 0750 /var/lib/mailsync
sudo install -d -o mailsync -g mailsync -m 0700 /var/lib/mailsync/creds
sudo install -d -o mailsync -g mail-ro  -m 2750 /var/lib/mailsync/pub
sudo install -d -o mailsync -g mail-ro  -m 2750 /var/lib/mail

# 2. credentials — pre-created 0600 so the secret never exists at a looser mode
sudo install -o mailsync -g mailsync -m 0600 /dev/null /var/lib/mailsync/creds/holten
sudo install -o mailsync -g mailsync -m 0600 /dev/null /var/lib/mailsync/creds/kit
pass mail/holten | head -1 | tr -d '\n' | sudo tee /var/lib/mailsync/creds/holten >/dev/null
pass kit         | head -1 | tr -d '\n' | sudo tee /var/lib/mailsync/creds/kit    >/dev/null

# 3. configs, handler, units
cd ~/config/mail
sudo install -d -o root -g root -m 0755 /usr/local/lib/mailsync
sudo install -o root -g root -m 0755 mailsync/fetch.sh /usr/local/lib/mailsync/fetch.sh
sudo install -o mailsync -g mailsync -m 0640 mailsync/mbsyncrc          /var/lib/mailsync/mbsyncrc
sudo install -o mailsync -g mailsync -m 0640 mailsync/goimapnotify.yaml /var/lib/mailsync/goimapnotify.yaml
sudo install -o root -g root -m 0644 mailsync/mbsync.service       /etc/systemd/system/
sudo install -o root -g root -m 0644 mailsync/mbsync.timer         /etc/systemd/system/
sudo install -o root -g root -m 0644 mailsync/goimapnotify.service /etc/systemd/system/
sudo systemctl daemon-reload
```

`tr -d '\n'` matters: `PassCmd` is `cat`, and a trailing newline would be sent
as part of the password.

Verify the boundary actually holds before going further — this failing is the
entire point of the exercise:

```bash
cat /var/lib/mailsync/creds/holten     # must fail: Permission denied
ls  /var/lib/mailsync/creds/           # must fail: Permission denied
ls  /var/lib/mail/holten/              # must succeed
touch /var/lib/mail/holten/x           # must fail: read-only for joseph
```

| | holten | kit |
|---|---|---|
| login | `joseph@holten.com` | `np6630` (**not** the address) |
| address | `joseph@holten.com` | `np6630@kit.edu` |
| credential | `pass mail/holten` | `pass kit` |

KIT's login being the account name rather than the address is the difference
most likely to produce a confusing `AUTHENTICATE` rejection later.

Note that `pass insert` writes `pass/password-store/mail/holten.gpg` **into
this repo**, tracked, as an encrypted blob. That is the existing pattern here
(see the overleaf and zenodo entries), but it is worth knowing.

## First run — do these in order and stop at the first failure

Each step isolates one failure mode, so a failure tells you what broke.

Everything that touches a credential now runs as `mailsync`, so these are
`sudo -u mailsync` rather than plain commands. Joseph cannot run them: the
config and the credential are both unreadable to him, by design.

```bash
# 1. config parses — no network, no credential
mbsync -c mail/mailsync/mbsyncrc -l nosuchchannel

# 2. THE key test: lists remote folders, transfers no mail.
#    Proves DNS + TLS + PassCmd + login all at once.
sudo -u mailsync mbsync -c /var/lib/mailsync/mbsyncrc -l holten

# 3. fetch, verbose
sudo -u mailsync mbsync -c /var/lib/mailsync/mbsyncrc -V holten

# 4. mail actually landed (joseph can read the maildir)
ls /var/lib/mail/holten/INBOX/cur | wc -l

# 5. index it — as joseph, the index is his
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
| `Permission denied` on the config | you ran it as joseph, not `sudo -u mailsync` |
| `AUTHENTICATE` rejected, credentials known good | trailing newline in the credential file — rewrite it with `tr -d '\n'` |
| host unreachable / timeout | wrong `Host` or `Port` |
| certificate error | wrong `CertificateFile`; for a private CA point it at that single PEM. For a STARTTLS-only server use `Port 143` + `TLSType STARTTLS` |
| `AUTHENTICATE` rejected | `User` form — try the bare login instead of the full address, or the server wants an app password |
| unknown keyword `Master`/`SSLType` | you copied a pre-1.4 tutorial; this file uses `Far`/`Near` and `TLSType` |

Run the same steps for `kit`. `User` there is already the account name
(`np6630`), which is what KIT wants; putting the address in would give
`AUTHENTICATE rejected`.

Note there is no longer a "does `pass` work" step: the fetch path does not
touch `pass`, gpg-agent, or the Yubikey at all. That is what makes it able to
run unattended, and it is why `pass` can now require a touch per use.

## Live delivery (IMAP IDLE)

mbsync has **no IDLE support** — on its own it can only ever poll. So a small
daemon holds the idle connection and pokes mbsync when something lands:

```
as mailsync ─────────────────────────────────────────────────────────
goimapnotify ──IDLE on holten INBOX──► fetch.sh holten
             ──IDLE on kit    INBOX──► fetch.sh kit
                                         ├─ mbsync <channel>  (ALL folders)
                                         └─ write pub/last-sync   ← the signal
                                                    │
as joseph ─────────────────────────────────────────┼─────────────────
                              mail-index.path (inotify) ◄┘
                                         └─► index-and-notify.sh
                                               ├─ notmuch new
                                               └─ notify-send   (dunst)
```

**INBOX is only the trigger, not the scope.** `fetch.sh` runs a plain
`mbsync <channel>`, so Archives, Sent, Invoices and the rest all sync too —
what gets synced is decided by `Patterns` in `mbsyncrc`, never by the caller.
Watching INBOX alone keeps this to *one* IMAP connection per account; omitting
`boxes` would open one IDLE connection per folder (~18), which hosts refuse.

The channel is an **argument**, so KIT mail doesn't drag holten through a sync
and vice versa. With no argument the script falls back to the `all` group,
which is how the timer covers both accounts in one run.

### Why a stamp file

The two halves run under different users, so they are supervised by different
systemd managers — one system, one per-user. `After=` / `Requires=` cannot
express a dependency across that line, so the coupling has to be **data**:
`fetch.sh` writes `/var/lib/mailsync/pub/last-sync` when it finishes, and
`mail-index.path` watches that file with inotify. Neither side waits on the
other, which is what makes an indeterminate sync duration a non-issue.

Three details that are easy to get wrong:

- It writes **content**, not `touch`. `touch` only updates mtime (`IN_ATTRIB`);
  a real write gives `IN_CLOSE_WRITE`, which is what `PathChanged=` catches.
- `PathChanged=`, not `PathExists=`. The latter is level-triggered and would
  re-fire forever unless the handler deleted the stamp.
- The stamp carries mbsync's **exit code**. `mailsync` has no session bus, so
  it cannot call `notify-send` itself — a failed fetch reaches a screen only
  because joseph's half reads the code out of the stamp and reports it.

`.path` units are edge-triggered and cannot fire for a sync that happened while
you were logged out, so `mail-index.service` is *also* `WantedBy=default.target`
and runs once at login.

### Units

Three system units, deployed with `sudo` (not `install.sh`):

| unit | |
|---|---|
| `goimapnotify.service` | the IDLE daemon, `Restart=always` |
| `mbsync.service` | oneshot, runs `fetch.sh` with no argument |
| `mbsync.timer` | fires it every 30 min as a backstop |

Two user units, symlinked by `install.sh`:

| unit | |
|---|---|
| `mail-index.path` | watches the stamp file |
| `mail-index.service` | `notmuch new` + `notify-send` |

`Restart=always` is for network drops and servers closing an IDLE connection
uncleanly. It used to exist because `passwordCMD` needed the Yubikey unlocked
at session start; that failure mode is gone, along with `Environment=DISPLAY=:0`
— nothing on the `mailsync` side draws a pinentry prompt anymore.

The timer exists because an IDLE connection can drop silently — suspend, NAT
timeout, server-side reset. 30 min is deliberately slow; it's a safety net,
not the primary path.

```bash
systemctl status goimapnotify               # is it connected?
journalctl -u goimapnotify -f               # watch it react
systemctl list-timers mbsync.timer          # when does the backstop fire?
sudo systemctl start mbsync.service         # force a sync now
systemctl --user status mail-index.path     # active (waiting) = armed
journalctl --user -u mail-index.service -n 20
cat /var/lib/mailsync/pub/last-sync         # "<unix-ts> <exit-code> <channels>"
```

The units are **system** units now, so `systemctl` without `--user` — a habit
worth rebuilding, since `systemctl --user status mbsync` will just say the unit
does not exist.

## Reading mail in Emacs

`emacs/init.el` has a `notmuch` block under the `SPC m` leader:

| key | |
|---|---|
| `SPC m m` | notmuch hello screen (saved searches) |
| `SPC m s` | `notmuch-search` |
| `SPC m c` | compose |
| `SPC m a` | compose, picking recipients from the address book |
| `SPC m u` | re-run `notmuch new` and refresh |

Inside a mail buffer the bindings are evil-collection's, not notmuch's own —
it shadows plain `r`/`R` in normal state:

| key | |
|---|---|
| `c r` | reply to sender |
| `c R` | reply to all |
| `c c` | compose |
| `C-c C-c` | send (in the compose buffer; `C-c C-k` abandons) |

`SPC m u` only re-indexes; it does **not** fetch — and joseph can no longer
fetch at all. Force one with `sudo systemctl start mbsync.service`, or wait for
IDLE or the 30 min timer.

It uses `:ensure nil` on purpose. Arch's `notmuch` package installs the elisp
into `/usr/share/emacs/site-lisp`, which is already on the load-path, and that
guarantees notmuch-emacs matches the notmuch CLI version. Taking it from MELPA
instead invites version skew between the two, which breaks in confusing ways.

## Sending

`mail/msmtprc` → `~/.msmtprc`, one account per IMAP account, each reading the
*same* `pass` entry mbsync uses. Emacs sends through it via
`message-send-mail-with-sendmail`.

**Which account a message goes out through is decided by the From header, in
two places that must agree**:

| | |
|---|---|
| msmtp | Emacs passes `-f <From>` (`message-sendmail-envelope-from 'header`); msmtp picks the account whose `from` matches, else `default` (holten) |
| `notmuch-fcc-dirs` | an alist in `emacs/init.el` — `"kit\\.edu"` → `kit/Gesendete Elemente`, `""` → `holten/Sent`, first match wins so the catch-all stays last |

If those disagree the mail is *sent* by one server and *filed* under the other,
and the next `mbsync` uploads it into the wrong account's Sent folder. Change
them together.

Because that one header decides both, `notmuch-always-prompt-for-sender` is on:
every compose, reply and forward asks **Send mail from:** first, defaulting to
`primary_email`. Upstream only honours that variable in `notmuch-mua-new-mail`
and in forwarding — replying reads a `C-u` prefix instead, and `SPC m a` calls
`notmuch-mua-mail` directly, which reads nothing. `emacs/init.el` closes both
gaps (an `:around` advice on `notmuch-mua-new-reply`, and an explicit `From` in
`notmuch-compose-to`), so all four paths prompt.

The candidate list is `primary_email` + `other_email` from `notmuch-config`, so
**every address in `other_email` needs an account in `msmtprc`** — one whose
`from` matches it literally. An address the picker offers but msmtp doesn't
know falls through to `account default : holten` and leaves via one.com, while
the Fcc still files it by regexp: exactly the mismatch above, now one keystroke
away. That is what `account kit-alias` is for; it is the same mailbox and
credential as `kit`, differing only in `from`.

Check the routing without sending anything, or touching the network or the
Yubikey:

```bash
msmtp --pretend --from=joseph.holten@kit.edu   # expect: using account kit-alias
```

The local Sent copy is what makes sent mail appear in notmuch immediately; the
next `mbsync` pushes it up.

## KIT is Exchange, and it shows

Two things about `kit` that were found the hard way and are not guessable:

**`AuthMechs LOGIN` is mandatory.** `AuthMechs` defaults to `*`, the server
advertises NTLM, and mbsync prefers it — then fails:

```
IMAP command 'AUTHENTICATE NTLM TlRMTVNTUAAB…' returned an error: AUTHENTICATE failed.
```

Pinning `LOGIN` skips SASL negotiation. The password is still safe: the whole
session is inside TLS already (IMAPS on 993).

**The folder names are German, and duplicated.** `mbsync -l kit` with a wide
`Patterns` gives the real list — never guess these:

| | |
|---|---|
| kept | `INBOX`, `Entwürfe` (drafts), `Gesendete Elemente` (sent), `Sent` |
| dropped | `Gelöschte Elemente` **and** `Trash` — two trashes; `Junk-E-Mail`; `Postausgang` (outbox) |
| dropped | `Kalender`, `Kontakte`, `Aufgaben`, `Notizen`, `Journal` — Exchange exposes calendar/contacts/tasks over IMAP, and they are not mail |

`Gesendete Elemente` is the one Outlook and OWA actually write to, which is why
`notmuch-fcc-dirs` targets it and not the leftover `Sent`.

Note `mbsync -l` **applies `Patterns`**, so it hides what you have excluded —
including, at first, the very folders you are trying to discover. To see
everything the server has, use the widened-copy trick from "Widening" above.

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
sed 's|^Patterns .*|Patterns "*"|' ~/config/mail/mailsync/mbsyncrc > /tmp/probe.rc
sudo -u mailsync mbsync -c /tmp/probe.rc -l holten
rm /tmp/probe.rc
```

It has to run as `mailsync` — the config's `PassCmd` reads a file joseph
cannot open. Run it as joseph and you get `Permission denied`, not a folder
list. (`sudo -u` is a plain process, so the units' `PrivateTmp=` does not
apply here and `/tmp` is fine.)

## Gotchas

- **A blank line ends a section in `mbsyncrc`.** Options after one are parsed
  as global keywords, giving errors like `'Patterns' is not a recognized
  section-starting or global keyword`. Comment lines are fine inside a
  section; empty ones are not. Keep each `IMAPAccount` / `MaildirStore` /
  `Channel` block contiguous.
- **isync >= 1.4 renamed everything.** `Master`/`Slave` → `Far`/`Near`,
  `SSLType` → `TLSType`. Arch ships 1.5.x. Most blog posts predate this.
- **Check the config parses without hitting the network or a credential**:
  `mbsync -c mail/mailsync/mbsyncrc -l nosuchchannel`. It reads the whole file,
  then errors only about the unknown channel — any real parse error shows up
  first, with a line number. This is the one mbsync command joseph can still
  run, since it never gets as far as `PassCmd`.
- **`notmuch config set` and `notmuch setup` rewrite the config file** and can
  replace the symlink with a regular file. Edit `notmuch-config` by hand; if a
  command does clobber it, re-run `install.sh`.
- **`new.ignore` is not optional.** mbsync keeps its state files inside the
  maildir (`SyncState *`), and notmuch will try to index them and error on
  every run without the ignore list.
- **`notmuch-config` uses the split form**: `database.mail_root` is
  `/var/lib/mail` (what mailsync writes) and `database.path` is
  `~/.local/state/notmuch` (the index, which joseph owns). They must stay
  separate — an index inside the maildir would sit in a tree joseph cannot
  write. `mail_root` being one level above `/var/lib/mail/holten` is what lets
  holten and kit share one index; a new account only has to put its maildir
  under `/var/lib/mail/` to join it, nothing enumerates accounts.
- **Rebuilding the index is free and safe**: `rm -rf ~/.local/state/notmuch &&
  notmuch new`. It never touches the mail itself, which is just as well —
  joseph could not damage the maildir if he tried.
- **A new account touches six files, not one.** See below — forgetting
  `notmuch-config` or `notmuch-fcc-dirs` fails quietly rather than loudly.

## Adding another account

`kit` was added this way; the checklist is what it cost.

| file | what to add |
|---|---|
| `mailsync/mbsyncrc` | `IMAPAccount` / `IMAPStore` / `MaildirStore` / `Channel` blocks, plus the channel name in the `Group all` block. `Path`/`Inbox` absolute under `/var/lib/mail/`, `PassCmd` a `cat` of the new credential file |
| `mailsync/goimapnotify.yaml` | another entry under `configurations:`, with `onNewMail: /usr/local/lib/mailsync/fetch.sh <channel>` |
| `msmtprc` | an `account` block **per sending address**, aliases included; leave `account default : holten` last |
| `notmuch-config` | the address in `other_email` (semicolon-separated for more than one) |
| `emacs/init.el` | a `notmuch-fcc-dirs` pair, before the `""` catch-all |
| `install.sh` | the manual-steps note |

Plus, outside the repo:

```bash
pass insert <entry>                      # for msmtp's passwordeval
sudo install -o mailsync -g mailsync -m 0600 /dev/null /var/lib/mailsync/creds/<acct>
pass <entry> | head -1 | tr -d '\n' | sudo tee /var/lib/mailsync/creds/<acct> >/dev/null
```

The maildir itself needs no `mkdir` — `Create Near` makes mbsync build it, and
it inherits `mail-ro` from the setgid bit on `/var/lib/mail`. The pass entry
lands in `pass/password-store/` **inside this repo**, tracked, so it needs a
commit like any other file.

Only `mailsync/mbsyncrc` plus the credential file are load-bearing for
*fetching*. The rest are the ways a second account goes subtly wrong: mail
filed to the wrong Sent folder, replies leaving through the wrong server,
notmuch treating your own address as a stranger's.

Then, in order:

```bash
mbsync -c mail/mailsync/mbsyncrc -l nosuchchannel              # parse
sudo -u mailsync mbsync -c /var/lib/mailsync/mbsyncrc -l <ch>  # auth/TLS
sudo -u mailsync mbsync -c /var/lib/mailsync/mbsyncrc -V <ch>  # fetch
notmuch new
sudo install -o mailsync -g mailsync -m 0640 \
     mail/mailsync/goimapnotify.yaml /var/lib/mailsync/goimapnotify.yaml
sudo systemctl restart goimapnotify
```

Editing anything under `mailsync/` in this repo has no effect until it is
re-deployed with `sudo install` — the runtime copies are copies, not symlinks,
because `mailsync` cannot read `$HOME`.

Gmail, if it's next, is not this easy: it needs an app password (or OAuth2, via
`xoAuth2` in goimapnotify), and its labels-as-folders mean `Patterns` wants
`!"[Gmail]/All Mail"` and `!"[Gmail]/Important"` — otherwise every message
arrives several times over.

## Next steps

Sync, sending, Emacs and the KIT account are all done (sections above). Left:

1. **`ykman openpgp keys set-touch enc on`.** Nothing unattended calls `pass`
   anymore — that was the only thing forcing the touch policy off. With it on,
   `msmtp` sending requires a physical Yubikey touch per message, so a rogue
   process running as joseph cannot send mail as you even though it can reach
   `passwordeval`. Do this only after the sync has run clean for a day; a
   surviving unattended `pass` caller would hang waiting for a finger.
2. A TUI — `aerc` or `neomutt`, both have notmuch backends.
3. `synchronize_flags=true`, so read/unread round-trips to the server instead
   of living only in the local index. **Not free under the uid split**: notmuch
   would start renaming maildir files, so every directory under `/var/lib/mail`
   needs `2770` instead of `2750` and the fetch units need `UMask=0007`.
   `rename(2)` needs write on the *directory*, not the file, so file modes can
   stay as they are. Local flag changes would also need to reach the server,
   which means a signal in the other direction — a stamp file joseph writes and
   a `mailsync`-side `.path` unit watching it, or just letting the 30 min timer
   pick it up.


## IDEAS
- filepicker like fuzzy search with notmuch?
- some kind of ai model reading my mail (privacy?) to find well-hidden mails fuzzy search doesnt
- more accounts: google (see "Adding another account" — gmail needs an app
  password and `[Gmail]/*` exclusions)
