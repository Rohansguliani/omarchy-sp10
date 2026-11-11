-- settings: the Settings window (rohansguliani.settings shell plugin) and the
-- keys that used to open separate Wi-Fi / Bluetooth / audio windows.

dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.settings/settings.lua")

-- Omarchy's Super+Ctrl+B/N/A open bar panels that no longer exist (those bar
-- widgets were removed); they open the matching Settings page instead.
local open = os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.settings/bin/settings-open "
hl.unbind("SUPER + CTRL + B")
hl.unbind("SUPER + CTRL + N")
hl.unbind("SUPER + CTRL + A")
o.bind("SUPER + CTRL + B", "Bluetooth settings", open .. "bluetooth")
o.bind("SUPER + CTRL + N", "Wi-Fi settings", open .. "wifi")
o.bind("SUPER + CTRL + A", "Sound settings", open .. "sound")
