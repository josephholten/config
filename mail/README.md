# mail — terminal-first email: mbsync → ~/mail → notmuch

Three independent pieces, no daemon and no mail client:

```
one.com ──mbsync holten──► ~/mail/holten/{INBOX,…}   Maildir
KIT     ──mbsync kit─────► ~/mail/kit/{INBOX,…}      Maildir
                              │
                        notmuch new
                              │
                      ~/mail/.notmuch/               ONE Xapian index
                              │
                      $ notmuch search …
```

Two accounts, one index. That is the whole reason `database.path` is `~/mail`
and not `~/mail/holten`: searches, threads and tags span both accounts, and
`notmuch search from:x` doesn't care which server the mail came from. The
accounts stay separate only where they must — credentials, Sent folder, and
which server a reply goes out through.

Configs live here and are symlinked out by `install.sh`. **All mail data and
sync state lives under `~/mail/`, which is not part of this repo** — nothing
here needs a `.gitignore` entry.

Sending mail (msmtp), a TUI (aerc/neomutt) and Emacs integration are
deliberately not set up yet. See "Next steps".

## Install

```bash
sudo pacman -S isync notmuch
pass insert mail/holten          # the IMAP password
pass insert kit                  # KIT — top-level entry, not mail/kit
mkdir -p ~/mail/holten ~/mail/kit
~/config/install.sh              # links mbsyncrc + notmuch-config
```

The two accounts name their credentials inconsistently — `pass mail/holten`
but `pass kit`. That is the existing store layout, not a typo; `PassCmd` /
`passwordCMD` / `passwordeval` in the three configs must match it.

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

Run the same six steps for `kit` — `pass kit`, `mbsync -l kit`, `mbsync -V
kit`, and so on. `User` there is already the account name (`np6630`), which is
what KIT wants; putting the address in would give `AUTHENTICATE rejected`.

## Live delivery (IMAP IDLE)

mbsync has **no IDLE support** — on its own it can only ever poll. So a small
daemon holds the idle connection and pokes mbsync when something lands:

```
goimapnotify ──IDLE on holten INBOX──► on-new-mail.sh holten
             ──IDLE on kit    INBOX──► on-new-mail.sh kit
                                         ├─ mbsync <that channel>  (ALL folders)
                                         ├─ notmuch new
                                         └─ notify-send            (dunst)
```

**INBOX is only the trigger, not the scope.** `on-new-mail.sh` runs a plain
`mbsync <channel>`, so Archives, Sent, Invoices and the rest all sync too —
what gets synced is decided by `Patterns` in `mbsyncrc`, never by the caller.
Watching INBOX alone keeps this to *one* IMAP connection per account; omitting
`boxes` would open one IDLE connection per folder (~18), which hosts refuse.

The channel is an **argument**, so KIT mail doesn't drag holten through a sync
and vice versa. With no argument the script falls back to the `all` group,
which is how the timer covers both accounts in one run.

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

`SPC m u` only re-indexes; it does **not** fetch. Run `mbsync holten` first (or
wait for the timer, once that exists).

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
  which is what lets holten and kit share one index. A new account only has to
  put its maildir under `~/mail/` to join it — nothing in `notmuch-config`
  enumerates accounts.
- **Rebuilding the index is free and safe**: `rm -rf ~/mail/.notmuch &&
  notmuch new`. It never touches the mail itself.
- **A new account touches six files, not one.** See below — forgetting
  `notmuch-config` or `notmuch-fcc-dirs` fails quietly rather than loudly.

## Adding another account

`kit` was added this way; the checklist is what it cost.

| file | what to add |
|---|---|
| `mbsyncrc` | `IMAPAccount` / `IMAPStore` / `MaildirStore` / `Channel` blocks, plus the channel name in the `Group all` block |
| `goimapnotify.yaml` | another entry under `configurations:`, with `onNewMail: …/on-new-mail.sh <channel>` |
| `msmtprc` | an `account` block **per sending address**, aliases included; leave `account default : holten` last |
| `notmuch-config` | the address in `other_email` (semicolon-separated for more than one) |
| `emacs/init.el` | a `notmuch-fcc-dirs` pair, before the `""` catch-all |
| `install.sh` | the manual-steps note (`pass insert`, `mkdir`) |

Plus `pass insert <entry>` and `mkdir -p ~/mail/<acct>`. The pass entry lands
in `pass/password-store/` **inside this repo**, tracked, so it needs a commit
like any other file.

Only `mbsyncrc` is load-bearing for *fetching*. The rest are the ways a second
account goes subtly wrong: mail filed to the wrong Sent folder, replies leaving
through the wrong server, notmuch treating your own address as a stranger's.

Then, in order: `mbsync -l nosuchchannel` (parse), `mbsync -l <channel>`
(auth/TLS), `mbsync -V <channel>` (fetch), `notmuch new`, and only then
`systemctl --user restart goimapnotify`.

Gmail, if it's next, is not this easy: it needs an app password (or OAuth2, via
`xoAuth2` in goimapnotify), and its labels-as-folders mean `Patterns` wants
`!"[Gmail]/All Mail"` and `!"[Gmail]/Important"` — otherwise every message
arrives several times over.

## Next steps

Sync, sending, Emacs and the KIT account are all done (sections above). Left:

1. A TUI — `aerc` or `neomutt`, both have notmuch backends.
2. `synchronize_flags=true`, so read/unread round-trips to the server instead
   of living only in the local index.


## IDEAS
- filepicker like fuzzy search with notmuch?
- some kind of ai model reading my mail (privacy?) to find well-hidden mails fuzzy search doesnt
- more accounts: google (see "Adding another account" — gmail needs an app
  password and `[Gmail]/*` exclusions)
