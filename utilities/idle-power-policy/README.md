# idle-power-policy

Omarchy locks (and turns the display off) after 5 minutes idle whatever the
power source, and never suspends. This makes idle depend on power, and gives
the power button one job:

| | Plugged in | On battery |
|---|---|---|
| Lock and display off | after 1 hour idle | after 5 minutes idle |
| Sleep | never (remote access keeps working) | after 10 minutes locked |
| Power button | lock and display off now; while locked, display back on | same |

Omarchy's own idle service still does the timing, so Stay Awake and apps that
block idle (a playing video) still work. The watcher only switches its lock
timeout (`idle.lock` in `~/.config/omarchy/shell.json`) when the power source
changes, within 15 seconds. The power button no longer opens Omarchy's power
menu; that's on Super+Escape.

Limits: a timeout change doesn't move an idle countdown already running, so
unplugging while the machine is already idle keeps the 1-hour deadline until
the next input. Nothing here can act at the disk password prompt, which runs
before any user service.

| File | Role |
|---|---|
| `home/.local/bin/omarchy-idle-power-policy` | the watcher (test overrides at the top) |
| `home/.config/systemd/user/omarchy-idle-power-policy.service` | runs it |
| `home/.local/bin/omarchy-power-button` | the power-button action |
| `home/.config/hypr/utilities/idle-power-policy.lua` | binds the power button |

Undo: `systemctl --user disable --now omarchy-idle-power-policy`, delete the
files above, and set `idle.lock` in `shell.json` back to `300`.
