-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Slimmer Omarchy floating-window titlebar (default 30). Set after
-- default.hypr.toggles, which loads the titlebar plugin and its options.
if hl.plugin.hyprbars then
  hl.config({ plugin = { hyprbars = { bar_height = 24 } } })
end

-- Helium has its own buttons in the tab row, so no Omarchy titlebar for it.
o.window("helium", { ["hyprbars:no_bar"] = true })

-- Helium's tab-row buttons and dragging, handled here instead of by Helium.
-- Hyprland tells every window it is maximized, so after one click Helium's own
-- maximize button stops sending requests (Omarchy also ignores app maximize
-- requests), and a full tab row leaves Helium no empty space to drag. This
-- left-click bind watches clicks without taking them from Helium and acts on
-- two regions of Helium's top row, measured from the window's right edge:
--   28-55 px:  Helium's maximize button -> toggle maximize
--   55-80 px:  Helium's minimize button -> minimize to the dock
--   82-165 px: new-tab, extensions and menu buttons -> press and drag moves the
--              window (a click without moving still reaches Helium). Skipped
--              while maximized: Hyprland un-maximizes a window as soon as a
--              drag starts, even if the mouse never moves, so every click on
--              those buttons would restore the window. Restore first (double-
--              click, the button or Ctrl+Shift+A), or Super+drag.
-- and a double-click anywhere between the address bar and those buttons (tabs
-- and the empty space after them) toggles maximize, like a title bar. Helium's
-- own double-click maximize fails for the same reason as its button. The
-- address bar is skipped (left max(400 px, 40%)) so double-clicking a word in
-- the URL still selects it.
-- Helium's buttons come from gsettings org.gnome.desktop.wm.preferences
-- button-layout ':minimize,maximize,close'; re-measure if that changes.
-- The bind runs on each press, and once more on release after it has started a
-- drag; that release call is skipped.
local HELIUM_ROW = 30
local HELIUM_DOUBLE_CLICK_MS = 400
local helium_dragging = false
local helium_last_press = nil
o.bind("mouse:272", "Helium tab-row maximize and drag", function()
  if helium_dragging then
    helium_dragging = false
    -- A drag can leave the tab row above the screen; once it has landed, bring
    -- the top edge back onto the monitor.
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
    return
  end

  local window = hl.get_active_window()
  local cursor = hl.get_cursor_pos()
  if not window or window.class ~= "helium" or not cursor then
    return
  end

  local from_top = cursor.y - window.at.y
  local from_right = window.at.x + window.size.x - cursor.x
  if from_top < 0 or from_top >= HELIUM_ROW then
    return
  end

  if from_right >= 28 and from_right < 55 then
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
  elseif from_right >= 55 and from_right < 80 then
    hl.exec_cmd("omarchy-hyprland-window-minimize " .. window.address)
  elseif from_right >= 82 and from_right < 165 then
    if (window.fullscreen or 0) == 0 then
      helium_dragging = true
      hl.dispatch(hl.dsp.window.drag())
    end
  elseif from_right >= 165 and cursor.x - window.at.x >= math.max(400, window.size.x * 0.4) then
    local last = helium_last_press
    if last and last.address == window.address
        and math.abs(cursor.x - last.x) <= 8 and math.abs(cursor.y - last.y) <= 8 then
      helium_last_press = nil
      hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    else
      local press = { address = window.address, x = cursor.x, y = cursor.y }
      helium_last_press = press
      hl.timer(function()
        if helium_last_press == press then
          helium_last_press = nil
        end
      end, { type = "oneshot", timeout = HELIUM_DOUBLE_CLICK_MS })
    end
  end
end, { mouse = true, non_consuming = true })
