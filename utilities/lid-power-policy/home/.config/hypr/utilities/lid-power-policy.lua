-- lid-power-policy: lid close/open go to omarchy-lid-power-policy, which
-- turns the laptop panel off when docked or on power and keeps watching while
-- the lid stays shut. locked = true: it also runs on the lock screen.
hl.unbind("switch:on:Lid Switch")
hl.unbind("switch:off:Lid Switch")
o.bind("switch:on:Lid Switch", nil, "~/.local/bin/omarchy-lid-power-policy close", { locked = true })
o.bind("switch:off:Lid Switch", nil, "~/.local/bin/omarchy-lid-power-policy open", { locked = true })
