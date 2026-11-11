-- shared/core.lua: helpers every window tool uses. Each tool loads this file
-- itself (it runs once), so load the tools, not this.

local wt = _G.windowtools or {}
_G.windowtools = wt

if wt.find_window then
  return wt
end

wt.root = os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/"

-- A window by Hyprland address ("0x..." or "address:0x..."); nil or "" means
-- the active window.
function wt.find_window(address)
  if not address or address == "" then
    return hl.get_active_window()
  end
  address = tostring(address):gsub("^address:", ""):lower()
  if address:sub(1, 2) ~= "0x" then
    address = "0x" .. address
  end
  for _, window in ipairs(hl.get_windows()) do
    if window.address == address then
      return window
    end
  end
  return nil
end

-- Focus a window (switching workspace if needed) and raise it above other
-- floating windows. Shell panels call this through
--   hyprctl eval 'windowtools.focus("0x...")'
-- Key callbacks must call it that way too (focus_later): a focus dispatched
-- from inside a key callback doesn't settle until the next input event.
function wt.focus(address)
  local window = wt.find_window(address)
  if not window then
    return
  end
  hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
  if window.floating then
    hl.dispatch(hl.dsp.window.bring_to_top())
  end
end

function wt.shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function wt.focus_later(address)
  hl.exec_cmd("hyprctl eval " .. wt.shell_quote(string.format('windowtools.focus("%s")', address)))
end

-- Send a command to the rohansguliani.windows shell plugin. `shell summon`
-- goes over the shell's own socket (~9 ms); a plugin IpcHandler call would
-- start a qs ipc client instead (~30 ms), which is felt on every Alt+Tab.
-- data is a JSON value (string), or nil.
function wt.shell(cmd, data)
  local payload = '{"cmd":"' .. cmd .. '"' .. (data and (',"data":' .. data) or "") .. "}"
  hl.exec_cmd("omarchy-shell -q shell summon rohansguliani.windows " .. wt.shell_quote(payload))
end

-- Omarchy gives every monitor its own block of ten workspaces (laptop 1-10,
-- next monitor 11-20, ...; default/hypr/monitor-workspaces.lua). The first
-- and last workspace id of the block holding `id`, and the desktop slot
-- (1-10) `id` is within its block.
function wt.block_range(id)
  local first = math.floor((id - 1) / 10) * 10 + 1
  return first, first + 9
end

function wt.slot_of(id)
  return (id - 1) % 10 + 1
end

-- A monitor's size in layout pixels: its mode divided by its scale, swapped
-- when it is rotated a quarter turn.
function wt.logical_size(monitor)
  local scale = (monitor.scale and monitor.scale > 0) and monitor.scale or 1
  local w, h = math.floor(monitor.width / scale + 0.5), math.floor(monitor.height / scale + 0.5)
  if (tonumber(monitor.transform) or 0) % 2 == 1 then
    w, h = h, w
  end
  return w, h
end

-- Load another tool by its path under the plugin folder, reporting a broken
-- file instead of stopping the whole Hyprland config.
function wt.load(relative)
  local ok, err = pcall(dofile, wt.root .. relative)
  if not ok then
    hl.exec_cmd("notify-send -u critical 'Window tools' " .. wt.shell_quote(tostring(err)))
  end
end

return wt
