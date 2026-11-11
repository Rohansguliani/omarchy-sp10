-- window-actions/helium-tabrow.lua: Helium's tab-row buttons and dragging.
--
-- Helium draws its own minimize/maximize/close in its tab row (gsettings
-- org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close',
-- browser.custom_chrome_frame on, and no Omarchy titlebar: the
-- hyprbars:no_bar rule below). Hyprland tells every
-- window it is maximized, so after one click Helium's own maximize stops
-- sending requests (Omarchy also ignores app maximize requests), Hyprland
-- ignores app minimize requests, and a full tab row leaves no space to drag.
--
-- A left-click bind watches clicks without taking them from Helium and acts on
-- Helium's top row, measured from the window's right edge:
--   28-55 px    maximize button -> windowtools.maximize
--   55-80 px    minimize button -> minimize to the dock
--   82-165 px   new-tab, extensions and menu buttons -> pressing and moving
--               more than DRAG_PX drags the window. A click that doesn't move
--               is left entirely to Helium: the drag starts only once the
--               pointer moves, because Hyprland's window drag takes the
--               button's release, and Helium opens and closes these buttons'
--               menus on release (so starting the drag on press broke them).
--               Skipped while maximized.
-- and a double-click between the address bar and those buttons (tabs and the
-- empty space after them) toggles maximize, like a title bar. The address bar
-- (left max(400 px, 40%)) is skipped so double-clicking a URL word selects it.
-- Re-measure if Helium's button layout changes.

local wt = dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/shared/core.lua")

-- Helium's own tab row replaces Omarchy's floating-window titlebar.
o.window("helium", { ["hyprbars:no_bar"] = true })

local ROW = 30
local DOUBLE_CLICK_MS = 400
local DRAG_PX = 6
local POLL_MS = 10
local last_press = nil
-- The press in the drag zone that hasn't been released yet, if any.
local held = nil

-- A drag can leave the tab row above the screen; once it has landed, bring
-- the top edge back onto the monitor.
local function after_drag()
  hl.timer(function()
    local dragged = hl.get_active_window()
    local monitor = dragged and dragged.monitor
    if not dragged or dragged.class ~= "helium" or not monitor then
      return
    end
    local y = math.max(monitor.y or 0, dragged.at.y)
    if y ~= dragged.at.y then
      hl.dispatch(hl.dsp.window.move({ x = dragged.at.x, y = y, relative = false }))
    end
  end, { type = "oneshot", timeout = 50 })
end

-- While the button is held, start the window drag once the pointer has moved.
local function watch(press)
  hl.timer(function()
    if held ~= press then
      return
    end
    local cursor = hl.get_cursor_pos()
    if cursor and (math.abs(cursor.x - press.x) > DRAG_PX or math.abs(cursor.y - press.y) > DRAG_PX) then
      press.dragging = true
      hl.dispatch(hl.dsp.window.drag())
      return
    end
    watch(press)
  end, { type = "oneshot", timeout = POLL_MS })
end

o.bind("mouse:272", "Helium tab-row maximize and drag", function()
  -- Hyprland calls a press bind again when the drag it started ends.
  if held and held.dragging then
    held = nil
    after_drag()
    return
  end

  local window = hl.get_active_window()
  local cursor = hl.get_cursor_pos()
  if not window or window.class ~= "helium" or not cursor then
    return
  end

  local from_top = cursor.y - window.at.y
  local from_right = window.at.x + window.size.x - cursor.x
  if from_top < 0 or from_top >= ROW then
    return
  end

  if from_right >= 28 and from_right < 55 then
    wt.maximize(window.address)
  elseif from_right >= 55 and from_right < 80 then
    hl.exec_cmd("omarchy-hyprland-window-minimize " .. window.address)
  elseif from_right >= 82 and from_right < 165 then
    local maximized = (window.fullscreen or 0) ~= 0 or (wt.is_maximized and wt.is_maximized(window))
    if not maximized then
      held = { x = cursor.x, y = cursor.y, dragging = false }
      watch(held)
    end
  elseif from_right >= 165 and cursor.x - window.at.x >= math.max(400, window.size.x * 0.4) then
    local last = last_press
    if last and last.address == window.address
        and math.abs(cursor.x - last.x) <= 8 and math.abs(cursor.y - last.y) <= 8 then
      last_press = nil
      wt.maximize(window.address)
    else
      local press = { address = window.address, x = cursor.x, y = cursor.y }
      last_press = press
      hl.timer(function()
        if last_press == press then
          last_press = nil
        end
      end, { type = "oneshot", timeout = DOUBLE_CLICK_MS })
    end
  end
end, { mouse = true, non_consuming = true })

-- The release: a press that never moved ends here, untouched.
o.bind("mouse:272", nil, function()
  if held and held.dragging then
    after_drag()
  end
  held = nil
end, { mouse = true, release = true, transparent = true, non_consuming = true })
