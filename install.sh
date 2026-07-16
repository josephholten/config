#!/usr/bin/env bash
# install.sh — wire up ~/config by symlinking files into place.
#
# Usage:  ./install.sh [desktop|laptop]
#
# The host argument selects the host-specific configs (autorandr, restic, ...).
# User-level links are created directly; the system-level section uses sudo.
# Existing real files/dirs are never overwritten — they are reported so you
# can inspect and remove them manually, then re-run.

set -euo pipefail
CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${1:-}"

# link REPO_PATH LINK — symlink $CONFIG/REPO_PATH to LINK (idempotent, non-destructive)
link() {
    local target="$CONFIG/$1" linkpath="$2"
    if [ ! -e "$target" ]; then
        echo "MISSING TARGET: $target"; return
    fi
    mkdir -p "$(dirname "$linkpath")"
    if [ -L "$linkpath" ]; then
        ln -sfnT "$target" "$linkpath"           # fix up existing link
    elif [ -e "$linkpath" ]; then
        echo "SKIP (exists, not a symlink — resolve manually): $linkpath"
    else
        ln -sT "$target" "$linkpath"
        echo "linked $linkpath -> $target"
    fi
}

echo "== dotfiles in \$HOME =="
link bashrc        ~/.bashrc
link bash_defs.sh  ~/.bash_defs.sh
link vimrc         ~/.vimrc
link xinitrc       ~/.xinitrc
link xprofile      ~/.xprofile
link Xresources    ~/.Xresources
link latexmkrc     ~/.latexmkrc
link git/config    ~/.gitconfig

echo "== whole directories into ~/.config =="
link i3            ~/.config/i3
link i3status      ~/.config/i3status
link rofi          ~/.config/rofi
link zathura       ~/.config/zathura
link matplotlib    ~/.config/matplotlib
link conky         ~/.config/conky

echo "== pass =="
link pass/password-store   ~/.password-store
link pass/pass-git-helper  ~/.config/pass-git-helper

echo "== single files (dirs hold unmanaged state, so link per file) =="
link emacs/init.el                  ~/.config/emacs/init.el
link emacs/dark-monochrome-theme.el ~/.config/emacs/dark-monochrome-theme.el
link claude/settings.json           ~/.claude/settings.json
link claude/statusline-command.sh   ~/.claude/statusline-command.sh
link ssh/config                     ~/.ssh/config
link gnupg/gpg.conf                 ~/.gnupg/gpg.conf
link gnupg/scdaemon.conf            ~/.gnupg/scdaemon.conf

echo "== scripts into ~/bin (xprofile/i3 expect these) =="
link cluster-load/cluster-load             ~/bin/cluster-load
link rofi/rofi-kblayout                    ~/bin/rofi-kblayout
link rofi/rofi-power-menu/rofi-power-menu  ~/bin/rofi-power-menu

if [ -n "$HOST" ]; then
    echo "== host-specific ($HOST) =="
    for profile in "$CONFIG/$HOST"/autorandr/*; do
        link "$HOST/autorandr/$(basename "$profile")" ~/.config/autorandr/"$(basename "$profile")"
    done
else
    echo "== no host given — skipping autorandr/restic (re-run with desktop|laptop) =="
fi

echo "== system files (sudo) =="
# ly can't read symlinks into /home before login -> hard link (same filesystem)
sudo ln -f "$CONFIG/ly/config.ini" /etc/ly/config.ini
# dispatcher scripts must be root-owned or NetworkManager ignores them -> copy
sudo install -m 755 "$CONFIG/captive-autologin/90-captive-autologin" /etc/NetworkManager/dispatcher.d/
sudo install -m 755 "$CONFIG/captive-autologin/captive-autologin" /usr/local/bin/
sudo ln -sfnT "$CONFIG/tz/09-timezone" /etc/NetworkManager/dispatcher.d/09-timezone
sudo cp "$CONFIG/logind.conf" /etc/systemd/logind.conf

cat <<EOF

== manual steps (not automated, see linux.md + per-tool READMEs) ==
 - git submodule update --init --recursive
 - make -C st install          # terminal (fork, edit config.h)
 - make -C batsignal install   # fullscreen_warning, needed by lock/battery chain
 - make -C xsecurelock install # saver_battery, needed by lock screen
 - yay -S pass-git-helper      # git/config expects /sbin/pass-git-helper
 - gpg: import private key from backup; public key is gnupg/$(basename "$CONFIG"/gnupg/*.asc)
 - restic: resticprofile --config $HOST/restic/profiles.yaml schedule
 - wireguard: copy wireguard/jvpn.conf.template to /etc/wireguard, fill in keys (server only)
 - dnsmasq.conf -> /etc/dnsmasq.conf (server only)
 - desktop/pacman.conf: merge IgnorePkg/HoldPkg lines into /etc/pacman.conf; hooks -> /etc/pacman.d/hooks
EOF
