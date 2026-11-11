-- spotlight-search: Spotlight appears instantly, with no Hyprland fade/slide on
-- its layer (its own fade is off via "reduceMotion" in
-- ~/.config/omarchy/spotlight.json). The Ctrl+Space binding itself stays in
-- bindings.lua, in the block Spotlight's setup tour manages.
hl.layer_rule({ match = { namespace = "^omarchy-spotlight$" }, no_anim = true, animation = "none" })
