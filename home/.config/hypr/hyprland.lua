-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Slimmer Omarchy floating-window titlebar (default 30). Set after
-- default.hypr.toggles, which loads the titlebar plugin and its options.
if hl.plugin.hyprbars then
  hl.config({ plugin = { hyprbars = { bar_height = 24 } } })
end

-- Utilities (~/omarchy-sp10/utilities/<name>/) keep their Hyprland settings in
-- ~/.config/hypr/utilities/<name>.lua. Each file loads on its own: one that
-- fails is reported with a notification and the others still load.
local utilities = io.popen('ls -1 "' .. os.getenv("HOME") .. '/.config/hypr/utilities/"*.lua 2>/dev/null')
if utilities then
  for path in utilities:lines() do
    local ok, err = pcall(dofile, path)
    if not ok then
      hl.exec_cmd("notify-send -u critical 'Hyprland utility failed to load' " .. string.format("%q", tostring(err)))
    end
  end
  utilities:close()
end
