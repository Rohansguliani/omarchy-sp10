# bluetooth-audio-switch

Sound moves to Bluetooth headphones or speakers the moment they connect,
however they connected: from Settings, by auto-reconnect when you put them on,
or from `bluetoothctl`.

Why: PipeWire keeps sending sound to the last output you picked. Omarchy only
switched outputs inside its own Bluetooth bar panel, so AirPods that
reconnected on their own (or were connected anywhere else) stayed silent.

| File | Role |
|---|---|
| `home/.config/pipewire/pipewire-pulse.conf.d/50-bluetooth-switch-on-connect.conf` | loads `module-switch-on-connect` with `blocklist=^alsa_`, so only Bluetooth outputs take over; plugging in a dock, monitor or USB audio doesn't |
| `home/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf` | connects the A2DP audio profiles when a Bluetooth device connects, so speakers and headphones expose their outputs without a manual profile switch |

Applies after `systemctl --user restart pipewire-pulse` (install.sh's file
step doesn't restart it; log out and back in also works).
