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

-- Add a new binding.
o.bind("ALT + 1", "Area screenshot to clipboard", "omarchy-capture-screenshot region copy")
o.bind("CTRL + ALT + S", "Suspend", "systemctl suspend")
hl.unbind("switch:on:Lid Switch")
hl.unbind("switch:off:Lid Switch")
o.bind("switch:on:Lid Switch", nil, "~/.local/bin/omarchy-lid-power-policy close", { locked = true })
o.bind("switch:off:Lid Switch", nil, "~/.local/bin/omarchy-lid-power-policy open", { locked = true })
o.bind("CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
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

-- Ctrl+Shift+A toggles maximize on the active window (like Super+Alt+F).
o.bind("CTRL + SHIFT + A", "Toggle maximize", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- Ctrl+Shift+1..0 moves the active window to workspace 1..10 and follows it,
-- like Super+Shift+number. Keycodes match the number row on any layout.
for workspace = 1, 10 do
  o.bind("CTRL + SHIFT + code:" .. tostring(workspace + 9), "Move window to workspace " .. workspace, o.workspaces.move_window(workspace))
end

-- Alt+Tab window switcher (plugin io.github.pablo-merino.altswitch): hold Alt,
-- tap Tab to step through every window (most recent first), release to switch.
-- Replaces Omarchy's blind Alt+Tab cycling.
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.pablo-merino.altswitch/altswitch.lua")
