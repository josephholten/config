# certs

the networks `KIT` and `eduroam` with `radius-wlan.scc.kit.edu` somehow didnt work with the system certificate,
because `wpa_supplicant` choked on multple certs in one blob. they seem to work with the `isrg-root.pem`.
