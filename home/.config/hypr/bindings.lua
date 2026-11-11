-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding. (Alt+1 / Alt+2 / Alt+` screenshots: utilities/shot.lua.)
o.bind("CTRL + ALT + S", "Suspend", "systemctl suspend")

-- Super+Ctrl+A/B/N open Settings pages: utilities/settings.lua.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- >>> spotlight setup tour (managed; rerun via "Run Setup Tour") >>>
hl.unbind("CTRL + SPACE")
o.bind("CTRL + SPACE", "Spotlight", "omarchy-shell shell toggle io.github.maajix.spotlight '{}'")
-- <<< spotlight setup tour <<<

-- Everything else (window tools, Displays, lid, mouse, Wi-Fi/Bluetooth
-- windows) is a utility in ~/omarchy-sp10/utilities/ with its own
-- ~/.config/hypr/utilities/<name>.lua, loaded by hyprland.lua.
