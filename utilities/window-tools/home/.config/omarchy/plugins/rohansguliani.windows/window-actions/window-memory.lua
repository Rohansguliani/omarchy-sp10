-- window-actions/window-memory.lua: floating windows keep their place on each
-- monitor, like macOS.
--
-- Hyprland keeps floating windows in layout coordinates. When monitors change
-- (undock, a different dock, a monitor moved in the Displays page), Omarchy
-- moves each desktop to a remaining monitor, but a window's coordinates are
-- only carried over by an offset, not mapped onto the new monitor. A window
-- from a big or differently placed monitor can end up partly or wholly off
-- screen, and on re-docking it doesn't go back where it was.
--
-- So each floating window's place is remembered per monitor (by model name,
-- since a dock renames connectors): its centre as a fraction of the monitor's
-- work area, its size, and whether it was maximized or snapped. After any
-- monitor change:
--   on the monitor it belongs to   exactly where it was
--   moved off it (monitor gone)    the same relative spot, size clamped;
--                                  maximized and snapped stay so. It goes back
--                                  when its monitor returns.
--   moved by you to another one    that becomes its monitor
--
-- Places are recorded on focus changes, when windows open, at the end of a
-- mouse move or resize, and after maximize/snap. Hyprland has no event for a
-- moved window, so those are the moments a place can have changed. The memory
-- lives in a file in Hyprland's runtime directory, so a config reload (which
-- restarts Lua) keeps it, and a new session starts clean.

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

local FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr/"
  .. (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "session") .. "/window-memory.lua"
local SETTLE_MS = 120

-- address -> { home = monitor identity, guest = bool,
--              places = { [identity] = { cx, cy, w, h, kind?, before? } } }
local memory = {}
do
  local ok, data = pcall(dofile, FILE)
  if ok and type(data) == "table" then
    memory = data
  end
end

-- True while monitors are changing: places read now are in flux.
local hold = false
local dirty = false

local function rel_string(r)
  return string.format("{ cx = %.5f, cy = %.5f, w = %d, h = %d }", r.cx, r.cy, r.w, r.h)
end

local function save()
  if not dirty then
    return
  end
  dirty = false
  local out = { "return {" }
  for address, m in pairs(memory) do
    out[#out + 1] = string.format("[%q] = { home = %q, guest = %s, places = {", address, m.home, tostring(m.guest == true))
    for id, p in pairs(m.places) do
      out[#out + 1] = string.format("  [%q] = { cx = %.5f, cy = %.5f, w = %d, h = %d, kind = %s, before = %s },",
        id, p.cx, p.cy, p.w, p.h, p.kind and string.format("%q", p.kind) or "nil",
        p.before and rel_string(p.before) or "nil")
    end
    out[#out + 1] = "} },"
  end
  out[#out + 1] = "}"
  local tmp = FILE .. ".tmp"
  local handle = io.open(tmp, "w")
  if handle then
    handle:write(table.concat(out, "\n"))
    handle:close()
    os.rename(tmp, FILE)
  end
end

local function managed(window)
  local workspace = window and window.workspace
  local fullscreen = window and window.fullscreen
  return window and window.mapped and window.floating and window.monitor and workspace
    and not workspace.special and (not fullscreen or fullscreen == 0)
end

-- A monitor by model (stable across docks and connectors); one without a
-- description, such as a virtual output, by its name.
local function identity(monitor)
  local description = monitor.description or ""
  return description ~= "" and description or monitor.name
end

local function connected(id)
  for _, monitor in ipairs(hl.get_monitors()) do
    if identity(monitor) == id then
      return true
    end
  end
  return false
end

-- A rect relative to a work area (centre as a fraction, size in pixels), and back.
local function relative(rect, area)
  return { cx = (rect.x + rect.w / 2 - area.x) / area.w, cy = (rect.y + rect.h / 2 - area.y) / area.h, w = rect.w, h = rect.h }
end

local function absolute(r, area)
  local w, h = math.min(r.w, area.w), math.min(r.h, area.h)
  local x = math.floor(area.x + r.cx * area.w - w / 2 + 0.5)
  local y = math.floor(area.y + r.cy * area.h - h / 2 + 0.5)
  x = math.max(area.x, math.min(x, area.x + area.w - w))
  y = math.max(area.y, math.min(y, area.y + area.h - h))
  return { x = x, y = y, w = w, h = h }
end

local function kind_of(window)
  if wt.is_maximized(window) then
    return "max"
  end
  local current = wt.geometry(window)
  for _, side in ipairs({ "left", "right" }) do
    if wt.same_rect(current, wt.half_rect(window.monitor, side)) then
      return side
    end
  end
  return nil
end

local function place_of(window)
  local area = wt.monitor_area(window.monitor)
  local place = relative(wt.geometry(window), area)
  place.kind = kind_of(window)
  local before = wt._saved and wt._saved[window.address]
  if place.kind and before then
    place.before = relative(before, area)
  end
  return place
end

-- Remember where `window` is. `by_user`: the user just put it there (a drag,
-- a move to another monitor), so its current monitor becomes its own.
local function record(window, by_user)
  if hold or not managed(window) then
    return
  end
  local id = identity(window.monitor)
  local m = memory[window.address]
  if m and not by_user then
    -- Away from its monitor (it went away), the spot it was given is only
    -- temporary: keep the place it has on its own monitor. On its own monitor
    -- again means it is on its way back, and restore() puts it in place.
    if m.guest then
      return
    end
    if id ~= m.home and not connected(m.home) then
      -- Its monitor just went away and restore() hasn't run yet.
      return
    end
  end
  m = m or { places = {} }
  m.places[id] = place_of(window)
  m.home = id
  m.guest = false
  memory[window.address] = m
  dirty = true
end

local function record_all(user_address)
  for _, window in ipairs(hl.get_windows()) do
    record(window, window.address == user_address)
  end
  save()
end

function wt.remember_soon(address)
  hl.timer(function()
    local window = wt.find_window(address)
    if window then
      record(window, false)
      save()
    end
  end, { type = "oneshot", timeout = 60 })
end

-- Put a window back from its remembered place on `monitor`.
local function put(window, place, monitor)
  local area = wt.monitor_area(monitor)
  local rect = place.kind and (place.kind == "max" and area or wt.half_rect(monitor, place.kind)) or absolute(place, area)
  if place.kind and place.before and wt._saved then
    wt._saved[window.address] = absolute(place.before, area)
  end
  if not wt.same_rect(wt.geometry(window), rect) then
    wt.move_rect(window, rect)
  end
end

-- A window nothing is remembered for, left with less than a grabbable strip
-- on screen: centre it, shrunk to fit.
local function rescue(window)
  local area = wt.monitor_area(window.monitor)
  local rect = wt.geometry(window)
  local w = math.min(rect.x + rect.w, area.x + area.w) - math.max(rect.x, area.x)
  local h = math.min(rect.y + rect.h, area.y + area.h) - math.max(rect.y, area.y)
  if w < 80 or h < 40 then
    wt.move_rect(window, absolute({ cx = 0.5, cy = 0.5, w = rect.w, h = rect.h }, area))
  end
end

local function restore(final)
  for _, window in ipairs(hl.get_windows()) do
    if managed(window) then
      local m = memory[window.address]
      local id = identity(window.monitor)
      if not m then
        rescue(window)
      elseif id == m.home then
        put(window, m.places[id], window.monitor)
        m.guest = false
        dirty = true
      elseif connected(m.home) then
        -- Its monitor is here but it isn't: someone moved it. It lives here now.
        m.places[id] = place_of(window)
        m.home = id
        m.guest = false
        dirty = true
      else
        put(window, m.places[m.home], window.monitor)
        m.guest = true
        dirty = true
      end
    end
  end
  if final then
    hold = false
  end
  save()
end

-- Monitors are settling (and Omarchy is moving desktops): stop recording,
-- then put every window in place. A second pass catches desktops Omarchy
-- moved after the first; both only move windows that are out of place.
local settling = 0
local function settle()
  hold = true
  settling = settling + 1
  local this = settling
  hl.timer(function() restore(false) end, { type = "oneshot", timeout = SETTLE_MS })
  hl.timer(function()
    if this == settling then
      restore(true)
    end
  end, { type = "oneshot", timeout = SETTLE_MS * 6 })
end

for _, event in ipairs({ "monitor.added", "monitor.removed", "monitor.layout_changed" }) do
  hl.on(event, settle)
end

hl.on("window.open", function(window)
  if window and window.address then
    local address = window.address
    hl.timer(function()
      local now = wt.find_window(address)
      if now then
        record(now, true)
        save()
      end
    end, { type = "oneshot", timeout = 150 })
  end
end)

hl.on("window.close", function(window)
  if window and window.address and memory[window.address] then
    memory[window.address] = nil
    dirty = true
    save()
  end
end)

hl.on("window.active", function()
  record_all(nil)
end)

hl.on("window.move_to_workspace", function(window)
  local address = window and window.address
  hl.timer(function() record_all(address) end, { type = "oneshot", timeout = 60 })
end)

-- The end of a mouse move or resize (Super+drag, titlebars, edges). Transparent
-- and non-consuming, so apps and the other release binds still get it.
for _, button in ipairs({ "mouse:272", "mouse:273" }) do
  o.bind(button, nil, function()
    hl.timer(function()
      local active = hl.get_active_window()
      record_all(active and active.address)
    end, { type = "oneshot", timeout = 60 })
  end, { mouse = true, release = true, transparent = true, non_consuming = true, ignore_mods = true })
end

-- A config reload restarts Lua, often because monitors were just rearranged
-- (the Displays page saves monitors.lua): settle as after a monitor change.
settle()
