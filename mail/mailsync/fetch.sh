#!/usr/bin/env bash
# Fetch mail as the mailsync user, then signal joseph's session to index it.
#
# Usage: fetch.sh [CHANNEL ...]        default: the `all` group
#
# Two callers, same as the old on-new-mail.sh had:
#   - mailsync/goimapnotify.yaml, once per account, passing that account's
#     channel ("holten" / "kit") when IMAP IDLE reports new INBOX mail
#   - mailsync/mbsync.service, on a timer with no argument, so every account
#
# This is the half of on-new-mail.sh that needs the credential. The other half
# (notmuch new + notify-send) cannot run here: mailsync has no session bus and
# does not own the notmuch index. It lives in ../index-and-notify.sh and is
# triggered by the stamp file written below.
#
# Deliberately not `set -e`: a failed fetch must still write the stamp, or the
# failure never reaches a screen.
set -uo pipefail

channels=("$@")
[ "${#channels[@]}" -eq 0 ] && channels=(all)

mbsync -c /var/lib/mailsync/mbsyncrc "${channels[@]}" 2>&1
rc=$?   # captured here on purpose: inside `if ! mbsync …` this is always 0

# The stamp is the ONLY channel from this uid to joseph's session. Written
# unconditionally, exit code included, so a failed sync is reported rather
# than being silently indistinguishable from "no new mail".
#
# Written with content rather than touch(1): touch only updates mtime
# (IN_ATTRIB), while a real write gives the watching .path unit an
# unambiguous IN_CLOSE_WRITE.
printf '%s %s %s\n' "$(date +%s)" "$rc" "${channels[*]}" \
    > /var/lib/mailsync/pub/last-sync

exit "$rc"
