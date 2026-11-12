-- idle-power-policy: the power button locks and turns the displays off
-- (another press while locked turns them back on). Replaces Omarchy's power
-- menu on that button; the menu is still on Super+Escape.

hl.unbind("XF86PowerOff")
o.bind("XF86PowerOff", "Lock and turn displays off", "~/.local/bin/omarchy-power-button", { locked = true })
