-- edge-snap/edge-snap.lua: drag a floating window to the left or right edge
-- of a screen to snap it to that half, with a preview of where it will land
-- (ported from rohanMacUtils snap's drag-to-edge).
--
-- Hyprland has no drag events, and drags started from an Omarchy titlebar
-- never reach key binds (the titlebar plugin takes the button). So a light
-- timer watches the active window: it is being dragged while it moves in step
-- with the cursor. When the cursor touches a screen's left or right edge
-- (within EDGE px) the preview shows that half. The drag has ended once the
-- window stops following the cursor, or when a left-button release reaches the
-- bind below (Super+drag, Helium's tab row); if the cursor was at an edge, the
-- window snaps there. A titlebar drag dropped with the mouse held perfectly
-- still snaps on the first movement after the drop.
--
-- For scripts: windowtools.edge_snap_state() returns the current drag, if any.

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

hl.layer_rule({ match = { namespace = "^omarchy-windows-edge-snap$" }, no_anim = true, animation = "none" })

local EDGE = 2 -- px from a screen's side that count as "at the edge"
local SLOP = 2 -- px the window may lag the cursor and still be dragged
local IDLE_MS = 40 -- poll interval while nothing is dragged
local DRAG_MS = 16 -- and while a drag is tracked

local last = nil -- previous sample of the active window and cursor
local drag = nil -- { address, offx, offy, w, h, start, side, monitor }
local timer = nil

local function sample()
  local window = hl.get_active_window()
  local cursor = hl.get_cursor_pos()
  if not window or not cursor or not window.floating or (window.fullscreen or 0) ~= 0 then
    return nil
  end
  return {
    address = window.address,
    x = window.at.x, y = window.at.y, w = window.size.x, h = window.size.y,
    cx = cursor.x, cy = cursor.y,
  }
end

-- "left", "right" or nil, and the monitor under the cursor.
local function edge_at(cx, cy)
  local monitor = hl.get_monitor_at(cx, cy)
  if not monitor then
    return nil
  end
  local w = wt.logical_size(monitor)
  if cx <= monitor.x + EDGE then
    return "left", monitor
  elseif cx >= monitor.x + w - 1 - EDGE then
    return "right", monitor
  end
  return nil, monitor
end

local function show_preview(side, monitor)
  local rect = wt.half_rect and wt.half_rect(monitor, side)
  if not rect then
    return
  end
  wt.shell("edgeSnapShow", string.format('{"monitor":"%s","x":%d,"y":%d,"w":%d,"h":%d}',
    monitor.name, rect.x - monitor.x, rect.y - monitor.y, rect.w, rect.h))
end

local function set_side(side, monitor)
  if drag.side == side and (not side or drag.monitor.name == monitor.name) then
    return
  end
  drag.side, drag.monitor = side, monitor
  if side then
    show_preview(side, monitor)
  else
    wt.shell("edgeSnapHide")
  end
end

local function finish()
  if not drag then
    return
  end
  local ended = drag
  drag = nil
  timer:set_timeout(IDLE_MS)
  if ended.side then
    wt.shell("edgeSnapHide")
    wt.snap_to(ended.side, ended.address, ended.monitor, ended.start)
  end
end

local function tick()
  local now = sample()
  if drag and (not now or now.address ~= drag.address) then
    drag.side = nil
    wt.shell("edgeSnapHide")
    finish()
  end

  if drag then
    local following = math.abs((now.x - now.cx) - drag.offx) <= SLOP
      and math.abs((now.y - now.cy) - drag.offy) <= SLOP
      and now.w == drag.w and now.h == drag.h
    if following then
      set_side(edge_at(now.cx, now.cy))
    else
      finish()
    end
  elseif now and last and last.address == now.address and last.w == now.w and last.h == now.h then
    local dx, dy = now.x - last.x, now.y - last.y
    if (dx ~= 0 or dy ~= 0)
        and math.abs(dx - (now.cx - last.cx)) <= SLOP and math.abs(dy - (now.cy - last.cy)) <= SLOP then
      drag = {
        address = now.address,
        offx = now.x - now.cx, offy = now.y - now.cy,
        w = now.w, h = now.h,
        start = { x = last.x, y = last.y, w = last.w, h = last.h },
      }
      timer:set_timeout(DRAG_MS)
      set_side(edge_at(now.cx, now.cy))
    end
  end
  last = now
end

timer = hl.timer(tick, { type = "repeat", timeout = IDLE_MS })

-- A release that reaches binds ends the drag at once. Transparent and
-- non-consuming, so Helium's tab-row release and apps still get it.
o.bind("mouse:272", nil, function()
  if drag then
    finish()
  end
end, { mouse = true, release = true, transparent = true, non_consuming = true, ignore_mods = true })

-- Tearing a tab out of Helium. Hyprland doesn't implement xdg-toplevel-drag,
-- so while a tab is dragged it is only a drag image, not a window, and the
-- watcher above has nothing to follow. Its window appears where the tab was
-- dropped: if that was at a screen's left or right edge, snap it there.
hl.on("window.open", function(window)
  if not window or window.class ~= "helium" then
    return
  end
  local cursor = hl.get_cursor_pos()
  if not cursor then
    return
  end
  local side, monitor = edge_at(cursor.x, cursor.y)
  if not side then
    return
  end
  local address = window.address
  -- Let the new window take its first size before replacing it.
  hl.timer(function()
    wt.snap_to(side, address, monitor)
  end, { type = "oneshot", timeout = 60 })
end)

function wt.edge_snap_state()
  return drag
end
