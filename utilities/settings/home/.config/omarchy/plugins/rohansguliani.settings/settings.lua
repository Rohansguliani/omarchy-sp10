-- settings.lua: Hyprland side of the Settings window. Load from your
-- Hyprland config (on this machine, ~/.config/hypr/utilities/settings.lua):
--   dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.settings/settings.lua")

-- A settings window: floating and centred on every kind of workspace.
o.window({ class = "^org.quickshell$", title = "^Settings$" }, { float = true, center = true, size = { 980, 700 } })
