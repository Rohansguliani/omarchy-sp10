# lean-services

Stops always-running services this setup doesn't use. Measured on the SP10:
the whole system idled at about 5% of one core, so this is housekeeping, not a
speed fix.

| Change | Why | Undo |
|---|---|---|
| Masks `omarchy-crash-watch` (user) | It keeps `journalctl -f` open all session (~220 MB resident, mostly reclaimable log cache) to announce crashes and offer an AI diagnosis. | `systemctl --user unmask --now omarchy-crash-watch` then `systemctl --user enable --now omarchy-crash-watch` |
| Disables `cups.service` and `cups.path`, keeps `cups.socket` | No printers are configured; printing (or `lpstat`) connects to the socket, which starts CUPS. `cups.path` watches a file that always exists, so it would start CUPS at every boot. | `sudo systemctl enable --now cups.service cups.path` |

Kept on purpose: `omarchy-fcitx5` (Omarchy's Shift+CapsLock compose sequences
need it), `avahi-daemon` (network printer and device discovery).

Needs: any machine. Everything is in `setup.sh`; it is idempotent and respects
`--dry-run`.
