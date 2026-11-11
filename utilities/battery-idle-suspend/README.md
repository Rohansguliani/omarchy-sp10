# battery-idle-suspend

Omarchy's idle settings lock the screen and turn the display off, but never
suspend. This suspends after 10 minutes locked on battery; plugged in, it
never does. It cannot help at the LUKS password prompt, which runs before any
user service.

| File | Role |
|---|---|
| `home/.local/bin/omarchy-battery-idle-suspend` | the watcher (test overrides at the top) |
| `home/.config/systemd/user/omarchy-battery-idle-suspend.service` | runs it |
