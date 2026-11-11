-- switcher/switcher.lua: Alt+Tab with live window thumbnails.
--
-- Hold Alt and tap Tab to step through the current desktop's windows, most
-- recently used first; release Alt to switch. Alt+Shift+Tab steps back,
-- Escape cancels. A quick tap switches to the previous window without the
-- panel ever drawing.
--
-- This half owns the keys and the state. The panel (switcher/Switcher.qml in
-- the rohansguliani.windows shell plugin) only draws what it is sent:
--   {"cmd":"switcherShow","data":{...}}, switcherSelect, switcherHide
--
-- Two Hyprland details shape it (both found by the altswitch plugin):
--   * Committing on Alt release can't be a keybind: a release bind on a
--     modifier only fires when the modifier is tapped alone. The raw key event
--     stream is read instead.
--   * Focusing from inside a key callback doesn't settle until the next input
--     event, so the focus is sent through hyprctl from outside the callback.

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

-- The panel stays mapped and moves on screen to show; without this Hyprland
-- animates that move as a slide down from the top.
hl.layer_rule({ match = { namespace = "^omarchy-windows-switcher$" }, no_anim = true, animation = "none" })

local state = { windows = {}, index = 1, active = false }

local function json_string(value)
  local escaped = tostring(value or "")
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("[%c]", function(c) return string.format("\\u%04x", c:byte()) end)
  return '"' .. escaped .. '"'
end

local function payload()
  local rows = {}
  for _, window in ipairs(state.windows) do
    rows[#rows + 1] = string.format(
      '{"address":%s,"title":%s,"appClass":%s,"w":%d,"h":%d}',
      json_string(window.address),
      json_string(window.title),
      json_string(window.class),
      math.floor(window.size.x),
      math.floor(window.size.y)
    )
  end
  local current = hl.get_active_workspace()
  local monitor = current and current.monitor
  return string.format('{"monitor":%s,"windows":[%s],"index":%d}',
    json_string(monitor and monitor.name or ""), table.concat(rows, ","), state.index - 1)
end

local function teardown()
  state.active = false
  state.windows = {}
  wt.shell("switcherHide")
end

local function commit()
  if not state.active then
    return
  end
  -- Read the address before teardown drops the snapshot.
  local target = state.windows[state.index]
  local address = target and target.address
  teardown()
  if address then
    wt.focus_later(address)
  end
end

local function snapshot()
  local current = hl.get_active_workspace()
  local current_id = current and current.id
  local windows = {}
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace
    if window.mapped and workspace and not workspace.special and workspace.id == current_id then
      windows[#windows + 1] = window
    end
  end
  table.sort(windows, function(a, b) return a.focus_history_id < b.focus_history_id end)
  return windows
end

-- The switch commits when the key acting as Alt is released. Which physical
-- key that is depends on the keyboard: Alt_L/Alt_R (64/108) normally, but a
-- keyboard with Alt and Super swapped (the MelGeek's cmd key) sends Alt from
-- the Super keycodes (133/134). So the modifier keys held when the switch
-- starts are remembered, and releasing any of them commits.
local MODIFIER_KEYCODES = { 64, 108, 133, 134 }
local held = {}
local function remember_alt()
  held = {}
  for _, code in ipairs(MODIFIER_KEYCODES) do
    if hl.is_key_down(code) then
      held[code] = true
    end
  end
  if next(held) == nil then
    held = { [64] = true, [108] = true }
  end
end

local function step(delta)
  if state.active then
    state.index = (state.index - 1 + delta) % #state.windows + 1
    wt.shell("switcherSelect", tostring(state.index - 1))
    return
  end

  state.windows = snapshot()
  if #state.windows == 0 then
    return
  end
  -- Entry 1 is the window you're on, so one tap lands on entry 2.
  state.index = delta % #state.windows + 1
  state.active = true
  remember_alt()
  wt.shell("switcherShow", payload())
end

-- Called by the panel: a clicked thumbnail, or its watchdog if an Alt release
-- was ever missed.
function wt.switcher_pick(index)
  if not state.active then
    return
  end
  local target = state.windows[(tonumber(index) or -1) + 1]
  teardown()
  if target then
    wt.focus(target.address)
  end
end

function wt.switcher_cancel()
  if state.active then
    teardown()
  end
end

hl.unbind("ALT + TAB")
hl.unbind("ALT + SHIFT + TAB")
hl.bind("ALT + TAB", function() step(1) end, { description = "Switch window" })
hl.bind("ALT + SHIFT + TAB", function() step(-1) end, { description = "Switch window (reverse)" })

local ESCAPE = 9
hl.on("input.keyboard.key", function(keycode, _, pressed)
  if not state.active then
    return
  end
  if pressed == 0 and held[keycode] then
    commit()
  elseif pressed == 1 and keycode == ESCAPE then
    wt.switcher_cancel()
  end
end)
