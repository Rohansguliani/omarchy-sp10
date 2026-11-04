-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      drag_3fg = 1,
      -- No double-tap-to-drag: three-finger drag replaces it, and with it on
      -- libinput holds back every tap-click to see if a drag follows.
      tap_and_drag = false,
    },
  },
})

hl.device({ name = "microsoft-surface-045e:09af-touchpad", sensitivity = 0.25 })

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- Four-finger left/right switches workspace instantly, without the 1:1
-- sliding animation: one swipe = one workspace, fired as soon as the fingers
-- travel SWIPE_TRIGGER units (not on lift). Fingers left -> next workspace.
local SWIPE_TRIGGER = 40
local swipe = { dx = 0, done = false }
hl.gesture({
  fingers = 4,
  direction = "horizontal",
  action = {
    start = function(e)
      swipe.dx, swipe.done = e.delta.x, false
    end,
    update = function(e)
      if swipe.done then
        return
      end
      swipe.dx = swipe.dx + e.delta.x
      if math.abs(swipe.dx) < SWIPE_TRIGGER then
        return
      end
      swipe.done = true
      local ws = hl.get_active_workspace()
      local id = ws and tonumber(ws.id)
      if not id or id < 1 then
        return
      end
      local target = math.max(1, math.min(10, id + (swipe.dx < 0 and 1 or -1)))
      if target ~= id then
        hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
      end
    end,
    finish = function()
      swipe.done = true
    end,
  },
})

-- Mission control: four-finger swipe up opens the Mirador workspace/window
-- overview; swipe down closes it (plugin: ~/.config/omarchy/plugins/mirador).
hl.gesture({
  fingers = 4,
  direction = "up",
  action = function()
    hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell summon mirador '{}'"))
  end,
})
hl.gesture({
  fingers = 4,
  direction = "down",
  action = function()
    hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell hide mirador"))
  end,
})

for workspace = 1, 10 do
  hl.workspace_rule({ workspace = tostring(workspace), persistent = true })
end

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
