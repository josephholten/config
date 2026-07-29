#!/usr/bin/env bash
# Fetch mail, reindex, and notify.
#
# Two callers:
#   - mail/goimapnotify.yaml, when IMAP IDLE reports new mail in INBOX (live)
#   - mail/mbsync.service, on a 30 min timer (backstop for a dropped IDLE)
#
# Deliberately not `set -e`: a failed fetch should still be reported, not
# silently kill the script.
set -uo pipefail

if ! mbsync holten 2>&1; then
    notify-send -a mail -u critical "Mail sync failed" \
        "mbsync holten returned $?. Yubikey plugged in? See journalctl --user -u mbsync"
    exit 1
fi

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
