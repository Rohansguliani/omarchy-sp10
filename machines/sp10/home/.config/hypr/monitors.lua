-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 2

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Displays are set from the Displays settings page (Spotlight: "Displays";
-- plugin ~/.config/omarchy/plugins/rohansguliani.displays), which rewrites the
-- block below. The laptop panel is matched by connector; external monitors by
-- description, because a dock renames its connectors (DP-8 today) between
-- plugs. Rules for monitors that are unplugged stay and apply when they return.
-- Lenovo ThinkVision T32UD-40: 32" 4K on the HP Thunderbolt Dock G4.
-- Sceptre C35: 35" 3440x1440 ultrawide on the HP USB-C/A Universal Dock G2
-- (DisplayLink; needs evdi-dkms + displaylink, connector DVI-I-1).
-- >>> displays (written by the Displays settings page) >>>
hl.monitor({ output = "eDP-1", mode = "2880x1920@120", position = "370x1440", scale = omarchy_monitor_scale })
hl.monitor({ output = "desc:Sceptre Tech Inc Sceptre C35 0000000000000", mode = "3440x1440@100", position = "0x0", scale = 1.25 })
hl.monitor({ output = "desc:Lenovo Group Limited T32UD-40 V30FAH5L", mode = "3840x2160@60", position = "0x0", scale = 1.5 })
-- <<< displays <<<

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
