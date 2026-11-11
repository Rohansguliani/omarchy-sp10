-- window-actions/edge-resize.lua: resizing floating windows by their borders,
-- macOS style.
--
--   - A left or right edge changes the width only; top or bottom, the height
--     only; a corner changes both.
--   - A window sharing the dragged left/right edge moves its side with it, so
--     two windows side by side resize together like split panes.
--
-- Why it replaces Hyprland's own: Hyprland resizes a floating window from its
-- nearest corner even when you grab a side, so a sideways drag also changed
-- the height, and a neighbour never followed. That resize also grabs the press
-- before any bind sees it, so it is turned off (general.resize_on_border =
-- false, in ~/.config/hypr/looknfeel.lua) and every border press lands here.
-- Presses anywhere else are passed on untouched (auto_consuming + { ok = false }).
--
-- The grab strip is GRAB px just outside each side, Hyprland's own border grab
-- area. The top strip sits above the window's titlebar, so titlebar drags
-- still move the window.
--
-- For scripts: windowtools.edge_resize_hit(x, y) says what a press there
-- would grab, if anything.

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

local GRAB = 8 -- px outside each side
local CORNER = 24 -- px from an end of a side that count as the corner
local MIN_W = wt.WIDTH_MIN or 200
local MIN_H = 120
local POLL_MS = 8
local MAX_DRAG_MS = 30000 -- safety: never follow the cursor longer than this
-- Windows drawn without an Omarchy titlebar (their hyprbars:no_bar rules).
local NO_BAR = { helium = true, ["dev.rohan.shot"] = true }

local drag = nil
local timer = nil

local function bar_height(window)
  if NO_BAR[window.class] then
    return 0
  end
  local h = hl.get_config("plugin:hyprbars:bar_height")
  return tonumber(h) or 0
end

local function rect_of(w)
  return { x = w.at.x, y = w.at.y, w = w.size.x, h = w.size.y }
end

local function inside(r, x, y)
  return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- Floating windows on the desktop each monitor is showing. (HL.Window.visible
-- is true for windows on hidden desktops too, so it can't be used here.)
local function floating_visible()
  local shown = {}
  for _, m in ipairs(hl.get_monitors()) do
    if m.active_workspace then
      shown[m.active_workspace.id] = true
    end
    if m.active_special_workspace then
      shown[m.active_special_workspace.id] = true
    end
  end
  local out = {}
  for _, w in ipairs(hl.get_windows()) do
    if w.mapped and w.floating and not w.hidden and (tonumber(w.fullscreen) or 0) == 0
        and w.workspace and shown[w.workspace.id] then
      table.insert(out, w)
    end
  end
  return out
end

-- The sides of `w` a press at (x, y) grabs: a table like { left = true }, or nil.
local function sides(w, x, y)
  local r = rect_of(w)
  local top = r.y - bar_height(w) -- the titlebar's top edge
  local bottom = r.y + r.h
  local left, right = r.x, r.x + r.w
  local s = {}
  local in_rows = y >= top - GRAB and y < bottom + GRAB
  local in_cols = x >= left - GRAB and x < right + GRAB
  if in_rows and x >= left - GRAB and x < left then
    s.left = true
  elseif in_rows and x >= right and x < right + GRAB then
    s.right = true
  end
  if in_cols and y >= top - GRAB and y < top then
    s.top = true
  elseif in_cols and y >= bottom and y < bottom + GRAB then
    s.bottom = true
  end
  -- Near an end of a side counts as the corner.
  if s.left or s.right then
    if y < top + CORNER then
      s.top = true
    elseif y >= bottom - CORNER then
      s.bottom = true
    end
  end
  if s.top or s.bottom then
    if x < left + CORNER then
      s.left = true
    elseif x >= right - CORNER then
      s.right = true
    end
  end
  if next(s) == nil then
    return nil
  end
  return s
end

local function hit(x, y)
  local wins = floating_visible()
  for _, w in ipairs(wins) do
    local s = sides(w, x, y)
    if s then
      local r = rect_of(w)
      local followers = {}
      local edge_only = (s.left or s.right) and not s.top and not s.bottom
      if edge_only then
        followers = wt.neighbours(w, r)[s.left and "left" or "right"]
      end
      -- The strip may lie over another window. Only a neighbour sharing the
      -- dragged edge may be under it; any other window keeps its click.
      local blocked = false
      for _, other in ipairs(wins) do
        if other.address ~= w.address and inside(rect_of(other), x, y) then
          local follower = false
          for _, n in ipairs(followers) do
            if n.window.address == other.address then
              follower = true
            end
          end
          blocked = blocked or not follower
        end
      end
      if not blocked then
        return { window = w, sides = s, r = r, followers = followers }
      end
    end
  end
  return nil
end

local function stop()
  drag = nil
  if timer then
    timer:set_enabled(false)
  end
end

local function tick()
  if not drag then
    return stop()
  end
  local window = wt.find_window(drag.address)
  local cursor = hl.get_cursor_pos()
  drag.ticks = drag.ticks + 1
  if not window or not cursor or drag.ticks * POLL_MS > MAX_DRAG_MS then
    return stop()
  end

  local r, s = drag.r, drag.sides
  local dx = (s.left or s.right) and math.floor(cursor.x - drag.cx + 0.5) or 0
  local dy = (s.top or s.bottom) and math.floor(cursor.y - drag.cy + 0.5) or 0
  local t = { x = r.x, y = r.y, w = r.w, h = r.h }

  if s.right then
    local most = math.huge
    for _, f in ipairs(drag.followers) do
      most = math.min(most, f.rect.x + f.rect.w - (r.x + r.w) - MIN_W)
    end
    dx = math.max(MIN_W - r.w, math.min(dx, most))
    t.w = r.w + dx
  elseif s.left then
    local least = -math.huge
    for _, f in ipairs(drag.followers) do
      least = math.max(least, f.rect.x + MIN_W - r.x)
    end
    dx = math.min(r.w - MIN_W, math.max(dx, least))
    t.x, t.w = r.x + dx, r.w - dx
  end
  if s.bottom then
    dy = math.max(MIN_H - r.h, dy)
    t.h = r.h + dy
  elseif s.top then
    dy = math.min(r.h - MIN_H, dy)
    t.y, t.h = r.y + dy, r.h - dy
  end

  if dx == drag.dx and dy == drag.dy then
    return
  end
  drag.dx, drag.dy = dx, dy

  wt.place_rect(window, t)
  for _, f in ipairs(drag.followers) do
    local other = wt.find_window(f.window.address)
    if other then
      if s.right then
        local seam = t.x + t.w
        wt.place_rect(other, { x = seam, y = f.rect.y, w = f.rect.x + f.rect.w - seam, h = f.rect.h })
      else
        wt.place_rect(other, { x = f.rect.x, y = f.rect.y, w = t.x - f.rect.x, h = f.rect.h })
      end
    end
  end
end

timer = hl.timer(tick, { type = "repeat", timeout = POLL_MS })
timer:set_enabled(false)

-- Press: take it on a border; otherwise pass it on.
o.bind("mouse:272", nil, function()
  local cursor = hl.get_cursor_pos()
  local grab = cursor and hit(cursor.x, cursor.y)
  if not grab then
    return { ok = false }
  end
  drag = {
    address = grab.window.address,
    sides = grab.sides,
    cx = cursor.x,
    cy = cursor.y,
    r = grab.r,
    followers = grab.followers,
    dx = 0,
    dy = 0,
    ticks = 0,
  }
  hl.dispatch(hl.dsp.focus({ window = "address:" .. grab.window.address }))
  timer:set_enabled(true)
end, { auto_consuming = true, transparent = true })

-- Release ends it. Non-consuming, so apps and other tools still see it.
o.bind("mouse:272", nil, function()
  if drag then
    tick()
    stop()
  end
end, { release = true, transparent = true, non_consuming = true, ignore_mods = true })

function wt.edge_resize_hit(x, y)
  local grab = hit(x, y)
  if not grab then
    return nil
  end
  local names, edges = {}, {}
  for _, f in ipairs(grab.followers) do
    table.insert(names, f.window.class)
  end
  for side in pairs(grab.sides) do
    table.insert(edges, side)
  end
  table.sort(edges)
  return { window = grab.window.class, edge = table.concat(edges, "+"), followers = names }
end
