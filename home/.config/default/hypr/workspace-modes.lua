-- Local override of Omarchy's default.hypr.workspace-modes (found first because
-- bootstrap puts ~/.config/?.lua ahead of $OMARCHY_PATH on package.path).
--
-- Loads Omarchy's own file and removes one call: unmaximize_others(window) in
-- the window.open handler, which un-maximizes every maximized window on a
-- floating workspace whenever another window opens there. Everything else is
-- Omarchy's code, so updates still apply. If the call is no longer found, the
-- original is used unchanged and a notification says so.

local path = (os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/workspace-modes.lua"
local file = assert(io.open(path, "r"))
local source = file:read("a")
file:close()

local patched, count = source:gsub("\n    unmaximize_others%(window%)\n", "\n", 1)
if count ~= 1 then
  patched = source
  hl.exec_cmd("notify-send -u critical 'Hyprland override' 'workspace-modes.lua changed upstream: keep-maximized patch not applied (~/.config/default/hypr/workspace-modes.lua)'")
end

return assert(load(patched, "@" .. path))()
