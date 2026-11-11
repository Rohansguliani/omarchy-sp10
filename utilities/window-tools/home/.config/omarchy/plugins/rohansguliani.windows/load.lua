-- load.lua: the one file to load from your Hyprland config (on this machine,
-- ~/.config/hypr/utilities/window-tools.lua):
--   dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/load.lua")
-- Each tool is its own file and can be loaded alone instead (Mission Control
-- needs desktops). A broken file is reported and the rest still load.

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

wt.load("desktops/desktops.lua")
wt.load("window-actions/window-actions.lua")
wt.load("window-actions/window-memory.lua")
wt.load("window-actions/edge-resize.lua")
wt.load("window-actions/helium-tabrow.lua")
wt.load("edge-snap/edge-snap.lua")
wt.load("switcher/switcher.lua")
wt.load("mission-control/mission-control.lua")
