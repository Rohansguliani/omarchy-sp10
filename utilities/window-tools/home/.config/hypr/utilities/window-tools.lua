-- window-tools: the rohansguliani.windows shell plugin's Hyprland half. Each
-- tool binds its own keys and gestures (see the plugin's README):
--   desktops/        Super+1..0, Super+Shift/Ctrl+Shift+1..0, Ctrl+Left/Right,
--                    four-finger left/right, Super+Alt+D (linked desktops)
--   window-actions/  Ctrl+Shift+A maximize, Alt+Left/Right snap, Helium tab row
--   switcher/        Alt+Tab with live thumbnails
--   mission-control/ Ctrl+Up, four-finger up/down
-- All are keysym bindings, so they work on any keyboard.
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/load.lua")
