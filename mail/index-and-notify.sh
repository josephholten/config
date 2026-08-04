#!/usr/bin/env bash
# Index newly fetched mail and notify — the joseph half of the old
# on-new-mail.sh.
#
# Triggered by ~/.config/systemd/user/mail-index.path, which watches the stamp
# file that mailsync/fetch.sh writes at the end of every sync. Also run once at
# login (mail-index.service is WantedBy=default.target), because .path units
# are edge-triggered and will not fire for mail fetched while logged out.
#
# Runs as joseph, not mailsync, for two reasons: the notmuch index is joseph's
# (mailsync has no business writing it, and emacs writes tags to it), and
# notify-send needs a session bus that a system service does not have.
#
# Deliberately not `set -e`: a stale or missing stamp should not stop indexing.
set -uo pipefail

STAMP=/var/lib/mailsync/pub/last-sync

# Stamp format: "<unix-ts> <mbsync-exit-code> <channels...>"
rc=0
chans="?"
if [ -r "$STAMP" ]; then
    read -r _ts rc chans < "$STAMP" || true
fi

# The only way a fetch failure reaches a screen — mailsync cannot call
# notify-send itself. Note this also fires at login if the last sync before
# logout failed; that is stale but not wrong.
if [ "${rc:-0}" -ne 0 ]; then
    notify-send -a mail -u critical "Mail sync failed" \
        "mbsync $chans exited $rc. See: journalctl -u mbsync -n 50"
fi

# Index regardless: a partial sync still delivers some mail.
# "Added 3 new messages to the database." -> 3
added=$(notmuch new 2>/dev/null | sed -n 's/^Added \([0-9]\+\) new message.*/\1/p')
[ "${added:-0}" -gt 0 ] 2>/dev/null || exit 0

# Newest `added` unread messages, one "Sender — Subject" per line, capped at 5
# so a big batch doesn't produce a notification the size of the screen.
body=$(notmuch search --sort=newest-first --limit="$added" --format=json 'tag:unread' \
       | jq -r '.[] | "\(.authors) — \(.subject)"' 2>/dev/null | head -5)

[ "$added" -gt 5 ] && body="$body"$'\n'"… and $((added - 5)) more"

notify-send -a mail -i mail-unread \
    "$added new message$([ "$added" -gt 1 ] && printf s)" "$body"
