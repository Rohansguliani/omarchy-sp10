-- shot: area screenshots, OCR and an annotate-and-copy editor
-- (~/.local/bin/shotd, user service shot.service).
--   Alt+1  drag an area -> PNG on the clipboard
--   Alt+2  drag an area -> its text on the clipboard
--   Alt+`  the last capture in the editor
-- The monitor under the cursor is the one frozen and selected on.

local function shot(mode)
  return function()
    local monitor = hl.get_active_monitor()
    local name = monitor and monitor.name or ""
    if not tostring(name):match("^[%w._-]*$") then
      name = ""
    end
    hl.dispatch(hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/shot " .. mode .. " " .. name))
  end
end

o.bind("ALT + 1", "Area screenshot to clipboard", shot("copy"))
o.bind("ALT + 2", "Copy text from an area (OCR)", shot("ocr"))
o.bind("ALT + grave", "Edit the last screenshot", shot("edit"))

-- Increase only the Surface touchpad while the selection layer exists. The
-- compositor closes the layer even if shotd crashes; restore the current
-- Devices setting rather than a hard-coded speed.
local touchpad = "microsoft-surface-045e:09af-touchpad"
local selections = 0
local original_config
local function configured_touchpad()
  local config
  local env = { hl = { device = function(rule)
    if rule.name == touchpad then config = rule end
  end } }
  local load, err = loadfile(os.getenv("HOME") .. "/.config/hypr/utilities/devices.lua", "t", env)
  if not load then return nil, err end
  local ok, message = pcall(load)
  if not ok then return nil, message end
  return config
end

hl.on("layer.opened", function(layer)
  if layer.namespace ~= "shot" then return end
  selections = selections + 1
  if selections ~= 1 then return end
  local config = configured_touchpad()
  if config and type(config.sensitivity) == "number" then
    original_config = config
    local boosted = {}
    for key, value in pairs(config) do boosted[key] = value end
    boosted.sensitivity = math.min(1, config.sensitivity + 0.35)
    hl.device(boosted)
  end
end)

hl.on("layer.closed", function(layer)
  if layer.namespace ~= "shot" or selections == 0 then return end
  selections = selections - 1
  if selections ~= 0 then return end
  local config = configured_touchpad() or original_config
  if config then hl.device(config) end
  original_config = nil
end)

-- The selection overlay appears and goes at once.
hl.layer_rule({ match = { namespace = "^shot$" }, no_anim = true, animation = "none" })
-- The editor: floating, its own toolbar instead of Omarchy's titlebar.
o.window("dev.rohan.shot", { float = true, center = true, ["hyprbars:no_bar"] = true })
