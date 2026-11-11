# settings

One Settings window (shell plugin `rohansguliani.settings`): Wi-Fi, Bluetooth,
Sound, Displays, Battery, About. Open it from Spotlight ("Settings", or a page
name: "Wi-Fi", "Bluetooth", "Sound", "Displays", "Battery"), or
`Super+Ctrl+N` / `B` / `A` for Wi-Fi, Bluetooth and Sound.

| Page | Shows |
|---|---|
| Wi-Fi | on/off; the network you're on (IP, Disconnect, Forget); networks used before, in range or not; other networks, with an inline password field |
| Bluetooth | on/off; connected devices; paired devices; nearby devices in pairing mode, with Pair |
| Sound | output device and volume, input device and volume, a volume and mute per app |
| Displays | drag to arrange, resolution, refresh rate, scale, rotation, with Keep/Revert |
| Devices | connected mice, touchpads and keyboards; click one for tracking speed, scroll speed, natural scrolling, acceleration or tap to click, or Swap Alt and Super (keyboards in Mac mode) |
| Battery | charge, state, time left, power mode, capacity and cycles |
| About | model, CPU, graphics, memory, storage, Omarchy, kernel |

Radios scan only while their page is on screen: Wi-Fi scanning and Bluetooth
discovery start when the page opens and stop when you leave it. Bluetooth and
power actions use Omarchy's own `omarchy-bluetooth-device` and
`omarchy-bluetooth-power`; the power mode uses `omarchy-powerprofiles-set`.

| File | Role |
|---|---|
| `home/.config/omarchy/plugins/rohansguliani.settings/` | the window (`Settings.qml`), one file per page (`pages/`), shared controls (`components/`), `bin/settings-open [page]`, `bin/displays-save` (writes only the marked block in `~/.config/hypr/monitors.lua`), `bin/devices list\|set` (Devices page backend; validates, applies live, writes only the marked block in `devices.lua`) |
| `home/.config/hypr/utilities/devices.lua` | per-device rules written by the Devices page; rules for unplugged devices stay |
| `home/.config/hypr/utilities/settings.lua` | floating window rule; Super+Ctrl+N/B/A |
| `home/.local/share/applications/omarchy-*.desktop` | the Spotlight entries |
| `home/.local/bin/omarchy-{wifi,bluetooth}-window`, `omarchy-wifi-connect` | used by Spotlight's own Wi-Fi/Bluetooth items |

Needs `rohansguliani.settings` in `~/.config/omarchy/shell.json`'s plugin list.
Replaces the earlier `displays` page and the nmrs / Overskride windows.
