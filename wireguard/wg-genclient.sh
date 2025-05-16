#!/bin/bash
set -euo pipefail

WGCONF=jvpn.conf
TEMPLATE=jvpn.conf.template

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo -n "Peer: "
read -er PEER
PRIVATE=$(wg genkey)
PUBLIC=$(echo $PRIVATE | wg pubkey)
IP=$(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' $WGCONF | sed 's/\/.*$//' | awk -F. '{ print $4 }' | sort -n | tail -1)
NEXT=$((IP + 1))

sed "s%<PRIVATE>%${PRIVATE}%g; s%<IP>%${NEXT}%g" $TEMPLATE > $WGCONF.$PEER

printf "\n# ${PEER}\n[Peer]\nPublicKey = ${PUBLIC}\nAllowedIPs = 10.9.0.${NEXT}/32\n" >> $WGCONF
systemctl reload wg-quick@jvpn

qrencode -t ansiutf8 < $WGCONF.$PEER
