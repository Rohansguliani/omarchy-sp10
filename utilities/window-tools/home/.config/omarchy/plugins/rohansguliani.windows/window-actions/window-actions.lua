-- window-actions/window-actions.lua: maximize and half-screen snapping for
-- floating windows.
--
-- Hyprland's "maximized" is a fullscreen mode. Only one window per workspace
-- can hold it, and focusing or opening any other window there takes it away
-- (misc:on_focus_under_fullscreen). That fights stacked floating windows: a new
-- window or an Alt+Tab un-maximizes the one underneath. Here a floating window
-- is instead moved and resized to fill its monitor's work area, and the
-- geometry it had before is kept so the same action puts it back. It stays an
-- ordinary floating window, so stacking, focus and dragging behave normally.
-- Tiled windows keep Hyprland's own maximize.
--
-- Keys:
--   Alt+A / Ctrl+Shift+A       toggle maximize
--   Alt+Left / Alt+Right       snap to that half; the same key again restores
--                              (global, so apps lose Alt+Left/Right)
--   Alt+= (or Alt++) / Alt+-   widen / narrow the window by 5% of the screen
--                              (hold to repeat). A window touching the edge
--                              that moves follows it, so two snapped halves
--                              move their shared border together.
-- For scripts and other tools (address "0x..."; omitted = active window):
--   windowtools.maximize([address]), windowtools.snap("left"|"right", [address]),
--   windowtools.width(1|-1, [address]), windowtools.is_maximized(window)

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

-- Geometry each window had before it was maximized or snapped, by address.
-- A config reload starts Lua afresh and forgets it; a maximized window then
-- restores to two thirds of the screen, centred.
wt._saved = wt._saved or {}
local saved = wt._saved

local TOLERANCE = 2

-- A monitor's usable area in layout coordinates: its logical size minus
-- whatever bars and panels reserve.
local function monitor_area(monitor)
  local w, h = wt.logical_size(monitor)
  local reserved = monitor.reserved or {}
  local left, top = reserved.left or 0, reserved.top or 0
  local right, bottom = reserved.right or 0, reserved.bottom or 0
  return { x = monitor.x + left, y = monitor.y + top, w = w - left - right, h = h - top - bottom }
end

local function work_area(window)
  return monitor_area(window.monitor)
end

local function monitor_targets(monitor)
  local area = monitor_area(monitor)
  local half = math.floor(area.w / 2)
  return {
    max = area,
    left = { x = area.x, y = area.y, w = half, h = area.h },
    right = { x = area.x + half, y = area.y, w = area.w - half, h = area.h },
  }
end

local function targets(window)
  return monitor_targets(window.monitor)
end

local function geometry(window)
  return { x = window.at.x, y = window.at.y, w = window.size.x, h = window.size.y }
end

local function same(a, b)
  return math.abs(a.x - b.x) <= TOLERANCE and math.abs(a.y - b.y) <= TOLERANCE
    and math.abs(a.w - b.w) <= TOLERANCE and math.abs(a.h - b.h) <= TOLERANCE
end

local function apply(window, rect)
  local target = "address:" .. window.address
  hl.dispatch(hl.dsp.window.resize({ x = rect.w, y = rect.h, relative = false, window = target }))
  hl.dispatch(hl.dsp.window.move({ x = rect.x, y = rect.y, relative = false, window = target }))
  if wt.remember_soon then
    wt.remember_soon(window.address)
  end
end

-- For window-memory.lua.
wt.monitor_area = monitor_area
wt.geometry = geometry
wt.same_rect = same
-- Place exactly, keeping any snap/maximize it can be restored from.
wt.move_rect = apply

-- Which of our own placements the window is in now, if any.
local function placement(window, rects)
  local current = geometry(window)
  for name, rect in pairs(rects) do
    if same(current, rect) then
      return name
    end
  end
  return nil
end

local function place(which, address)
  local window = wt.find_window(address)
  if not window then
    return
  end

  if not window.floating then
    if which == "max" then
      hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle", window = "address:" .. window.address }))
    end
    return
  end

  -- A floating window can still hold Hyprland's own maximize (Super+Alt+F).
  -- Leave it first; for maximize that is the whole toggle.
  if (window.fullscreen or 0) == 1 then
    local address_now = window.address
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = "address:" .. address_now }))
    if which ~= "max" then
      hl.timer(function() place(which, address_now) end, { type = "oneshot", timeout = 30 })
    end
    return
  end

  local rects = targets(window)
  local current = placement(window, rects)

  if current == which then
    local previous = saved[window.address]
    saved[window.address] = nil
    if previous then
      apply(window, previous)
    elseif which == "max" then
      -- Maximized with nothing to go back to: two thirds, centred.
      local area = rects.max
      local w, h = math.floor(area.w * 2 / 3), math.floor(area.h * 2 / 3)
      apply(window, { x = area.x + math.floor((area.w - w) / 2), y = area.y + math.floor((area.h - h) / 2), w = w, h = h })
    end
    return
  end

  -- Moving between our own placements (left -> max) keeps the original size.
  if not current then
    saved[window.address] = geometry(window)
  end
  apply(window, rects[which])
  local active = hl.get_active_window()
  if active and active.address == window.address then
    hl.dispatch(hl.dsp.window.bring_to_top())
  end
end

function wt.maximize(address)
  place("max", address)
end

function wt.snap(side, address)
  if side == "left" or side == "right" then
    place(side, address)
  end
end

function wt.is_maximized(window)
  return window ~= nil and window.floating and placement(window, targets(window)) == "max"
end

-- The rect a half-snap to `side` ("left"/"right") gives on `monitor`.
function wt.half_rect(monitor, side)
  return monitor_targets(monitor)[side]
end

-- Put a floating window in `side`'s half of `monitor` (it may be dragged in
-- from another one), remembering `previous` for the same snap key to restore.
function wt.snap_to(side, address, monitor, previous)
  local window = wt.find_window(address)
  local rect = monitor and wt.half_rect(monitor, side)
  if not window or not window.floating or not rect then
    return
  end
  saved[window.address] = previous or geometry(window)
  apply(window, rect)
end

-- Width steps, ported from rohanMacUtils snap's width_hotkey/linked_followers.
local WIDTH_STEP = 0.05 -- of the work area's width, per press
local WIDTH_MIN = 200
-- Edges this close count as shared. Generous on purpose: Helium and other
-- clients round their size by a few pixels, and a mouse resize can leave two
-- halves overlapping slightly, which used to unlink them.
local LINK_GAP = 20
local LINK_MIN_OVERLAP = 40 -- and must share this much height
wt.WIDTH_MIN = WIDTH_MIN

-- Floating windows on the same workspace whose right edge touches `rect`'s
-- left edge ("left") or whose left edge touches its right edge ("right").
function wt.neighbours(window, rect)
  local out = { left = {}, right = {} }
  local ws = window.workspace and window.workspace.id
  for _, other in ipairs(hl.get_windows()) do
    if other.address ~= window.address and other.mapped and other.floating
        and (other.fullscreen or 0) == 0 and other.workspace and other.workspace.id == ws then
      local o = geometry(other)
      local overlap = math.min(rect.y + rect.h, o.y + o.h) - math.max(rect.y, o.y)
      if overlap >= LINK_MIN_OVERLAP then
        if math.abs(o.x + o.w - rect.x) <= LINK_GAP then
          table.insert(out.left, { window = other, rect = o })
        elseif math.abs(o.x - (rect.x + rect.w)) <= LINK_GAP then
          table.insert(out.right, { window = other, rect = o })
        end
      end
    end
  end
  return out
end
local neighbours = wt.neighbours

-- Place a window exactly (x, y, w, h) and forget any snap/maximize it had.
function wt.place_rect(window, rect)
  saved[window.address] = nil
  apply(window, rect)
end

-- Grow (+1) or shrink (-1) the window's width. A window flush with one screen
-- edge grows away from it; otherwise it grows about its centre. Neighbours
-- touching an edge that moves keep their far edge and follow the near one.
function wt.width(direction, address)
  local window = wt.find_window(address)
  if not window or not window.floating or (window.fullscreen or 0) ~= 0 then
    return
  end
  local area = work_area(window)
  local b = geometry(window)
  local new_w = math.floor(math.max(WIDTH_MIN, math.min(area.w, b.w + area.w * WIDTH_STEP * direction)) + 0.5)
  if math.abs(new_w - b.w) < 1 then
    return
  end
  local x0, x1 = b.x, b.x + b.w
  local ax0, ax1 = area.x, area.x + area.w
  local flush_l, flush_r = x0 <= ax0 + TOLERANCE, x1 >= ax1 - TOLERANCE
  local nx
  if flush_l and not flush_r then
    nx = x0
  elseif flush_r and not flush_l then
    nx = x1 - new_w
  else
    nx = x0 - math.floor((new_w - b.w) / 2)
  end
  nx = math.max(ax0, math.min(nx, ax1 - new_w))
  local target = { x = nx, y = b.y, w = new_w, h = b.h }

  local near = neighbours(window, b)
  -- A follower that would get narrower than WIDTH_MIN stops the step.
  for _, n in ipairs(near.left) do
    if target.x - n.rect.x < WIDTH_MIN then
      return
    end
  end
  for _, n in ipairs(near.right) do
    if n.rect.x + n.rect.w - (target.x + target.w) < WIDTH_MIN then
      return
    end
  end

  -- Resized windows no longer match a saved placement, so drop their memory.
  saved[window.address] = nil
  apply(window, target)
  if target.x ~= x0 then
    for _, n in ipairs(near.left) do
      saved[n.window.address] = nil
      apply(n.window, { x = n.rect.x, y = n.rect.y, w = target.x - n.rect.x, h = n.rect.h })
    end
  end
  if target.x + target.w ~= x1 then
    for _, n in ipairs(near.right) do
      local right = n.rect.x + n.rect.w
      saved[n.window.address] = nil
      apply(n.window, { x = target.x + target.w, y = n.rect.y, w = right - (target.x + target.w), h = n.rect.h })
    end
  end
end

if not wt._window_actions_watching then
  wt._window_actions_watching = true
  hl.on("window.close", function(window)
    if window and window.address then
      saved[window.address] = nil
    end
  end)
end

o.bind("CTRL + SHIFT + A", "Toggle maximize", function() wt.maximize() end)
hl.unbind("CTRL + SHIFT + W")
o.bind("CTRL + SHIFT + W", "Close window", hl.dsp.window.close())
o.bind("ALT + A", "Toggle maximize", function() wt.maximize() end)
o.bind("ALT + LEFT", "Snap window left", function() wt.snap("left") end)
o.bind("ALT + RIGHT", "Snap window right", function() wt.snap("right") end)
o.bind("ALT + equal", "Widen window", function() wt.width(1) end, { repeating = true })
o.bind("ALT + SHIFT + equal", "Widen window", function() wt.width(1) end, { repeating = true })
o.bind("ALT + minus", "Narrow window", function() wt.width(-1) end, { repeating = true })
