# Sourced by install.sh. Uses its DRY, run and note; $DIR is this folder.

# Omarchy's crash announcer keeps `journalctl -f` open for the whole session.
# A migration enables it, so mask it rather than only disabling it.
if [[ $(systemctl --user is-enabled omarchy-crash-watch.service 2>/dev/null) == masked ]]; then
  note "omarchy-crash-watch already masked"
else
  run systemctl --user mask --now omarchy-crash-watch.service
fi

# No printers are set up: CUPS starts on demand through cups.socket (any
# print or lpstat connects to it) instead of running all the time.
# cups.path goes too: it watches /var/cache/cups/org.cups.cupsd, which always
# exists, so it would start CUPS at every boot. Disabling cups.service also
# disables the units in its Also=, so the socket is enabled again after.
if systemctl cat cups.service &>/dev/null; then
  for unit in cups.service cups.path; do
    if systemctl is-enabled -q "$unit" 2>/dev/null || systemctl is-active -q "$unit"; then
      run sudo systemctl disable --now "$unit"
    fi
  done
  if systemctl is-enabled -q cups.socket 2>/dev/null; then
    note "cups.socket enabled (CUPS starts on demand)"
  else
    run sudo systemctl enable --now cups.socket
  fi
fi
