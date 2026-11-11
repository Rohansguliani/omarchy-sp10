# logitech-mx-master

MX Master 2S on the Unifying receiver, with no Solaar or Logitech software.

| Control | Does |
|---|---|
| Gesture button (under the thumb) | Mission Control (window-tools) |
| Thumb wheel | previous/next desktop, one per notch |
| Cursor / wheel | set in Settings > Devices (saved in `~/.config/hypr/utilities/devices.lua`) |

| File | Role |
|---|---|
| `home/.local/bin/mx-master` | Python daemon. Diverts the gesture button over HID++ 2.0 (re-diverts on every reconnect) and reads the thumb wheel from evdev. Logs each action: `journalctl --user -u mx-master` |
| `home/.config/systemd/user/mx-master.service` | runs it in the graphical session |
| `system/etc/udev/rules.d/70-mx-master.rules` | gives the logged-in user the receiver's hidraw node and the mouse's event node, nothing else |

Needs `python-evdev`. Thumb-wheel direction: `FORWARD_IS_NEXT` in `mx-master`,
then `systemctl --user restart mx-master`.
