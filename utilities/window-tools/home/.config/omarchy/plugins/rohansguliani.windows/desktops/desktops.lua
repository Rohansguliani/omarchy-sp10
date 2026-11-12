-- desktops/desktops.lua: desktops 1-10, linked across monitors, with empty
-- desktops skipped when stepping.
--
-- Omarchy gives every monitor its own ten workspaces. Linked (the default with
-- more than one monitor): desktop N is slot N on every monitor at once, so one
-- desktop spans all screens, like macOS with "Displays have separate Spaces"
-- off. Hyprland can't stretch one workspace over two monitors, so each
-- monitor's own workspace for that slot is switched together. Separate: each
-- monitor switches on its own (Omarchy's default). Remembered in LINK_FILE.
--
-- Keys and gestures:
--   Super+1..0                  go to desktop N
--   Ctrl+Shift+1..0             move the active window to desktop N and follow
--   Ctrl+Left / Ctrl+Right,
--   four-finger swipe left/right previous / next desktop with windows
--   Super+Alt+D                 link or separate desktops across monitors

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

local LINK_FILE = os.getenv("HOME") .. "/.local/state/omarchy/linked-desktops"

local function read_linked()
  local file = io.open(LINK_FILE, "r")
  if not file then
    return true
  end
  local value = file:read("l")
  file:close()
  return value ~= "0"
end

wt.linked = read_linked()

-- Desktops span every monitor right now: linked and more than one monitor.
function wt.spans_monitors()
  return wt.linked and #hl.get_monitors() > 1
end

function wt.set_linked(on)
  wt.linked = on and true or false
  local file = io.open(LINK_FILE, "w")
  if file then
    file:write(wt.linked and "1\n" or "0\n")
    file:close()
  end
end

function wt.toggle_linked()
  wt.set_linked(not wt.linked)
  hl.exec_cmd("notify-send -t 1500 'Desktops' " .. wt.shell_quote(wt.linked and "Linked: desktops span all screens" or "Separate: each screen switches on its own"))
  if wt.linked then
    -- Line the other screens up with this one.
    local workspace = hl.get_active_workspace()
    local id = workspace and tonumber(workspace.id)
    if id and id > 0 then
      wt.goto_desktop(wt.slot_of(id))
    end
  end
end

-- Go to desktop `slot` (1-10). Linked: every monitor shows its slot, and
-- focus stays on the monitor you were on, with the cursor left where it is.
function wt.goto_desktop(slot)
  local active = hl.get_active_monitor()
  if not active then
    return
  end
  wt.created[slot] = true
  if not wt.spans_monitors() then
    o.workspaces.focus(slot, active.name)()
    wt.desktop_changed()
    return
  end
  hl.config({ cursor = { no_warps = true } })
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.name ~= active.name then
      o.workspaces.focus(slot, monitor.name)()
    end
  end
  o.workspaces.focus(slot, active.name)()
  hl.config({ cursor = { no_warps = false } })
  wt.desktop_changed()
end

-- Called after every desktop switch. Mission Control replaces it to follow the
-- switch while it is open.
function wt.desktop_changed() end

-- Move the active window to desktop `slot` and follow it.
function wt.move_to_desktop(slot)
  o.workspaces.move_window(slot, false)()
  wt.goto_desktop(slot)
end

-- Desktops you have opened (Super+N, Mission Control's +, switching) stay in
-- the row and in stepping while empty, like macOS Spaces, until closed in
-- Mission Control. In memory only: a Hyprland restart forgets empty ones.
wt.created = wt.created or {}

-- Desktop slots (1-10) in use, as a set: those holding windows (on any
-- monitor when desktops span monitors, otherwise the focused monitor's) plus
-- the ones opened and not closed.
function wt.used_slots(windows_only)
  local active = hl.get_active_workspace()
  local first = wt.block_range(active and tonumber(active.id) or 1)
  local all = wt.spans_monitors()
  local used = {}
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace
    local wid = window.mapped and workspace and not workspace.special and tonumber(workspace.id)
    if wid and wid > 0 and (all or wt.block_range(wid) == first) then
      used[wt.slot_of(wid)] = true
    end
  end
  if not windows_only then
    for slot in pairs(wt.created) do
      used[slot] = true
    end
  end
  return used
end

-- Step to the previous or next desktop in use (see used_slots), skipping
-- slots never opened, without wrapping. Stepping right past the last one
-- opens a new empty desktop, like macOS's "+", but only from a desktop that
-- has windows, so there is never more than one empty desktop at the end.
function wt.step_desktop(delta)
  local workspace = hl.get_active_workspace()
  local id = workspace and tonumber(workspace.id)
  if not id or id < 1 then
    return
  end
  local used = wt.used_slots()
  local current = wt.slot_of(id)
  local slot = current + delta
  while slot >= 1 and slot <= 10 do
    if used[slot] then
      wt.goto_desktop(slot)
      return
    end
    slot = slot + delta
  end
  if delta > 0 and current < 10 and wt.used_slots(true)[current] then
    wt.goto_desktop(current + 1)
  end
end

-- Keycodes match the number row on any layout (10 = "1" ... 19 = "0").
-- Super+N switches; Ctrl+Shift+N moves the active window there and follows
-- (it replaces Omarchy's Super+Shift+N, which is left unbound).
for slot = 1, 10 do
  local key = "code:" .. tostring(slot + 9)
  hl.unbind("SUPER + " .. key)
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind("CTRL + SHIFT + " .. key)
  o.bind("SUPER + " .. key, "Switch to desktop " .. slot, function() wt.goto_desktop(slot) end)
  o.bind("CTRL + SHIFT + " .. key, "Move window to desktop " .. slot, function() wt.move_to_desktop(slot) end)
end
hl.unbind("CTRL + LEFT")
hl.unbind("CTRL + RIGHT")
o.bind("CTRL + RIGHT", "Next desktop", function() wt.step_desktop(1) end)
o.bind("CTRL + LEFT", "Previous desktop", function() wt.step_desktop(-1) end)
o.bind("SUPER + ALT + D", "Link or separate desktops across monitors", function() wt.toggle_linked() end)

-- Four-finger left/right: one swipe steps one desktop, as soon as the fingers
-- travel SWIPE_TRIGGER units (not on lift), with no sliding animation.
-- Fingers left -> next desktop.
local SWIPE_TRIGGER = 20
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
      wt.step_desktop(swipe.dx < 0 and 1 or -1)
    end,
    finish = function()
      swipe.done = true
    end,
  },
})
