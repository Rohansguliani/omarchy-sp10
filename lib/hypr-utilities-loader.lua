
-- Utilities (~/omarchy-sp10/utilities/<name>/) keep their Hyprland settings in
-- ~/.config/hypr/utilities/<name>.lua. Each file loads on its own: one that
-- fails is reported with a notification and the others still load.
local utilities = io.popen('ls -1 "' .. os.getenv("HOME") .. '/.config/hypr/utilities/"*.lua 2>/dev/null')
if utilities then
  for path in utilities:lines() do
    local ok, err = pcall(dofile, path)
    if not ok then
      hl.exec_cmd("notify-send -u critical 'Hyprland utility failed to load' " .. string.format("%q", tostring(err)))
    end
  end
  utilities:close()
end
