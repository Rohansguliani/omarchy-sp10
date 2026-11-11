-- devices: per-device input settings (pointer speed, scrolling, keyboard
-- options). Written by Settings > Devices (plugin rohansguliani.settings,
-- bin/devices); only the lines between the markers are rewritten. Rules for
-- devices that aren't plugged in stay and apply when they return.
-- >>> devices (written by the Devices settings page) >>>
hl.device({ name = "microsoft-surface-045e:09af-touchpad", sensitivity = 0.25 })
hl.device({ name = "glorious-model-d", sensitivity = -0.2, scroll_factor = 1.9, natural_scroll = false })
hl.device({ name = "logitech-mx-master-2s-1", sensitivity = -0.3, scroll_factor = 1.6 })
hl.device({ name = "melgeek-o2-c1-keyboard", kb_options = "omarchy:shift_caps_compose,altwin:swap_lalt_lwin" })
-- <<< devices <<<
