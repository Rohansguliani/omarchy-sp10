-- mission-control/mission-control.lua: Mission Control's gestures, keys, and
-- the window moves it asks for. Needs desktops/desktops.lua (loaded first).
--
-- Four-finger swipe up opens Mission Control (mission-control/MissionControl.qml
-- in the rohansguliani.windows shell plugin); swipe down closes it.
-- Ctrl+Shift+Up toggles it.

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

-- The panel stays mapped and moves on screen to show; without this Hyprland
-- animates that move as a slide down from the top.
hl.layer_rule({ match = { namespace = "^omarchy-windows-overview$" }, no_anim = true, animation = "none" })

-- Everything Mission Control draws, read once here, so it never rebuilds
-- itself when a window title changes while it is open.
-- Desktops are slots 1-10. When desktops span monitors, a desktop is that slot
-- on every monitor, so every monitor's windows are included; otherwise only
-- the focused monitor's. Positions (windows and monitors) are layout pixels
-- relative to the focused monitor's top-left. Windows are most recently
-- focused first.
function wt.overview_snapshot()
  local current = hl.get_active_workspace()
  local current_id = current and tonumber(current.id) or 1
  local first = wt.block_range(current_id)
  local focused = current and current.monitor
  local mx = focused and focused.x or 0
  local my = focused and focused.y or 0
  local all = wt.spans_monitors()

  local monitors = {}
  for _, monitor in ipairs(hl.get_monitors()) do
    if all or (focused and monitor.name == focused.name) then
      local w, h = wt.logical_size(monitor)
      monitors[#monitors + 1] = string.format('{"name":"%s","x":%d,"y":%d,"w":%d,"h":%d}',
        monitor.name, math.floor(monitor.x - mx), math.floor(monitor.y - my), w, h)
    end
  end

  local windows = {}
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace
    local id = workspace and not workspace.special and tonumber(workspace.id)
    if window.mapped and id and id > 0 and (all or wt.block_range(id) == first) then
      windows[#windows + 1] = window
    end
  end
  table.sort(windows, function(a, b) return a.focus_history_id < b.focus_history_id end)

  local used = {}
  for slot in pairs(wt.used_slots()) do
    used[#used + 1] = tostring(slot)
  end
  local rows = {}
  for _, window in ipairs(windows) do
    rows[#rows + 1] = string.format('{"address":"%s","slot":%d,"x":%d,"y":%d,"w":%d,"h":%d}',
      window.address, wt.slot_of(window.workspace.id),
      math.floor(window.at.x - mx), math.floor(window.at.y - my),
      math.floor(window.size.x), math.floor(window.size.y))
  end
  return string.format('{"current":%d,"first":%d,"monitor":"%s","used":[%s],"monitors":[%s],"windows":[%s]}',
    current_id, first, focused and focused.name or "", table.concat(used, ","),
    table.concat(monitors, ","), table.concat(rows, ","))
end

-- Move a window to desktop `slot` (1-10) without following it: the same slot
-- in its own monitor's block, so a window on another screen stays on that
-- screen. Called when a thumbnail is dropped on a desktop.
function wt.move_to_slot(address, slot)
  local window = wt.find_window(address)
  slot = tonumber(slot)
  local wid = window and window.workspace and tonumber(window.workspace.id)
  if not wid or wid < 1 or not slot or slot < 1 or slot > 10 then
    return
  end
  local target = wt.block_range(wid) + math.floor(slot) - 1
  hl.dispatch(hl.dsp.window.move({ window = "address:" .. window.address, workspace = tostring(target), follow = false }))
  wt.shell("overviewUpdate", wt.overview_snapshot())
end

-- Close desktop `slot`: its windows (every monitor's when desktops span
-- monitors) move to the desktop to its left in Mission Control's row, or to
-- its right when it is the first. The row is the desktops in use (with
-- windows, or opened and still empty) plus the current one. If the current desktop closes, the view follows its windows.
function wt.close_desktop(slot)
  slot = tonumber(slot)
  if not slot or slot < 1 or slot > 10 then
    return
  end
  local active = hl.get_active_workspace()
  local active_id = active and tonumber(active.id) or 1
  local current_slot = wt.slot_of(active_id)
  local row = wt.used_slots()
  row[current_slot] = true
  local target
  for s = slot - 1, 1, -1 do
    if row[s] then target = s break end
  end
  if not target then
    for s = slot + 1, 10 do
      if row[s] then target = s break end
    end
  end
  if not target then
    return
  end
  wt.created[slot] = nil

  local first = wt.block_range(active_id)
  local all = wt.spans_monitors()
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace
    local wid = window.mapped and workspace and not workspace.special and tonumber(workspace.id)
    if wid and wid > 0 and wt.slot_of(wid) == slot and (all or wt.block_range(wid) == first) then
      hl.dispatch(hl.dsp.window.move({ window = "address:" .. window.address, workspace = tostring(wt.block_range(wid) + target - 1), follow = false }))
    end
  end

  if slot == current_slot then
    wt.goto_desktop(target)
  end
  wt.shell("overviewUpdate", wt.overview_snapshot())
end

-- Reorder desktops (a desktop card dragged along Mission Control's row).
-- `order` lists the row's slots in their new order, e.g. "3,1,5" for a row of
-- 1,3,5 with desktop 3 dragged to the front. The i-th smallest slot then holds
-- what order[i] held: its windows (every monitor's when desktops span
-- monitors) and whether it was opened while empty. The view stays with the
-- desktop you were on.
function wt.reorder_desktops(order)
  local new, seen = {}, {}
  for word in tostring(order):gmatch("%d+") do
    local s = tonumber(word)
    if s < 1 or s > 10 or seen[s] then
      return
    end
    seen[s] = true
    new[#new + 1] = s
  end
  local positions = {}
  for i, s in ipairs(new) do
    positions[i] = s
  end
  table.sort(positions)
  local dest, changed = {}, false
  for i, s in ipairs(new) do
    dest[s] = positions[i]
    changed = changed or s ~= positions[i]
  end
  if not changed then
    return
  end

  local active = hl.get_active_workspace()
  local active_id = active and tonumber(active.id) or 1
  local current_slot = wt.slot_of(active_id)
  local first = wt.block_range(active_id)
  local all = wt.spans_monitors()
  -- Collect first, then move, so a window is never moved twice.
  local moves = {}
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace
    local wid = window.mapped and workspace and not workspace.special and tonumber(workspace.id)
    local to = wid and wid > 0 and dest[wt.slot_of(wid)]
    if to and to ~= wt.slot_of(wid) and (all or wt.block_range(wid) == first) then
      moves[#moves + 1] = { window.address, wt.block_range(wid) + to - 1 }
    end
  end
  for _, m in ipairs(moves) do
    hl.dispatch(hl.dsp.window.move({ window = "address:" .. m[1], workspace = tostring(m[2]), follow = false }))
  end

  local created = {}
  for s, v in pairs(wt.created) do
    created[dest[s] or s] = v
  end
  wt.created = created

  if dest[current_slot] and dest[current_slot] ~= current_slot then
    wt.goto_desktop(dest[current_slot])
  end
  wt.shell("overviewUpdate", wt.overview_snapshot())
end

-- cmd: "overviewOpen", "overviewClose" or "overviewToggle".
function wt.overview(cmd)
  if cmd == "overviewClose" then
    wt.shell(cmd)
  else
    wt.shell(cmd, wt.overview_snapshot())
  end
end

-- Set by the overlay as it opens and closes. While it is open, a desktop
-- switch (Ctrl+Left/Right, swipes, Super+N) redraws it on the new desktop.
wt.overview_open = wt.overview_open or false
function wt.desktop_changed()
  if wt.overview_open then
    wt.shell("overviewUpdate", wt.overview_snapshot())
  end
end

o.bind("CTRL + UP", "Mission Control", function() wt.overview("overviewToggle") end)

-- Opens as soon as the fingers travel SWIPE_TRIGGER units, not when they lift.
local SWIPE_TRIGGER = 15
local swipe = { dy = 0, done = false }
hl.gesture({
  fingers = 4,
  direction = "vertical",
  action = {
    start = function(e)
      swipe.dy, swipe.done = e.delta.y, false
    end,
    update = function(e)
      if swipe.done then
        return
      end
      swipe.dy = swipe.dy + e.delta.y
      if math.abs(swipe.dy) < SWIPE_TRIGGER then
        return
      end
      swipe.done = true
      wt.overview(swipe.dy < 0 and "overviewOpen" or "overviewClose")
    end,
    finish = function()
      swipe.done = true
    end,
  },
})
