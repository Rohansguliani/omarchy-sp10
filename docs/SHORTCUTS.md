# Input and Shortcut Plan

Verified against the active Hyprland Lua files on 2026-09-11.

| Input | Desired behavior | Status | Current configuration |
|---|---|---|---|
| Three-finger drag | Left-click-and-drag for selecting text and dragging files, tabs, and controls | **Done** | `drag_3fg = 1` in `~/.config/hypr/input.lua`. Double-tap-to-drag is off (`tap_and_drag = false`). libinput is a locally patched build (`libinput 1.32.0-1.1`, `~/libinput-sp10/pkg/`): three fingers always drag (never a swipe or pinch), the drag starts immediately, and it releases 300 ms after lift instead of 700 ms |
| Four-finger horizontal swipe | Instant workspace switching, no animation | **Done** | Live Lua gesture in `~/.config/hypr/input.lua`: one swipe = one workspace, fires after 40 units of travel (`SWIPE_TRIGGER`), clamped to 1–10 |
| `Alt+1` | Select an area and copy the screenshot directly to the clipboard | **Done** | `omarchy-capture-screenshot region copy` in `~/.config/hypr/bindings.lua` |
| `Alt+Tab` | Switch to the next window | **Done** | Omarchy default; `Alt+Shift+Tab` switches to the previous window |
| `Ctrl+Left` / `Ctrl+Right` | Switch to previous/next workspace | **Done** | Global bindings to `e-1` / `e+1` in `~/.config/hypr/bindings.lua` |
| `Ctrl+Alt+S` | Suspend the computer | **Done** | Runs `systemctl suspend` |
| Lid close/open | Battery suspend; plugged-in display off; restore on open | **Done** | logind policy plus `~/.local/bin/omarchy-lid-power-policy` |
| `Ctrl+Space` | Open a Raycast-style launcher (apps, files, calculator, windows) | **Done** | Spotlight plugin (`io.github.maajix.spotlight`); binding in `~/.config/hypr/bindings.lua`, managed by Spotlight's settings |
| Four-finger swipe up / down | Mission control: overview of workspaces and their windows | **Done** | Mirador plugin (`mirador`); gestures in `~/.config/hypr/input.lua`. Mirador's optional key bindings (Alt+Tab, Super+Tab, Shift+Tab, Super+W/arrows/numbers) were deliberately not installed |
| `Super+F` | Toggle the active window between floating and tiled | **Superseded** | Floating is now the default workspace layout (Omarchy 4.5). `Super+L` cycles a workspace between tiling, scrolling and floating; `Super+M` minimizes to the dock |
| `Super+Shift+Backspace` | Toggle fully gapless/borderless layout | **Done** | Omarchy default retained |

Notes:

- `Ctrl+Left` and `Ctrl+Right` are global, so applications do not receive them for word-wise cursor movement.
- `Ctrl+Shift+A` (toggle maximize) and `Ctrl+Shift+1`–`0` (move the window to workspace 1–10 and follow it) are global, set in `~/.config/hypr/bindings.lua`. Apps no longer receive them; for example, Helium's tab search (`Ctrl+Shift+A`) is gone.
- The bottom bar auto-hides; touch the bottom edge to show it. It now holds only the Taskbar (left) and the clock (`M/d h:mm AP`, right). The Omarchy menu button, workspace numbers, indicators, world clock, weather, update icon, tray, agents, Bluetooth, network, audio, display and power widgets were removed from the layout in `~/.config/omarchy/shell.json`. Their panels still open with `Super+Ctrl+A` (audio), `Super+Ctrl+N` (network) and `Super+Ctrl+B` (Bluetooth); the Omarchy menu is `Super+Space`. Restore the stock layout with `omarchy bar defaults`. The Taskbar plugin (`marcho78.taskbar`, after the workspace numbers) shows the current desktop's windows. Minimized windows show dimmed on every desktop. Click a window to focus it; click the focused one to minimize it; click a dimmed one to restore it to the current desktop. Omarchy's dock (`omarchy.dock`) is disabled; re-enable it with `omarchy plugin enable omarchy.dock`. Hover previews are off (`windowPreviews` false). `Taskbar.qml` has two local patches: `iconCandidates` (icons come from each app's desktop entry, not only its window class) and no width animation. `omarchy plugin update marcho78.taskbar` would overwrite both.
- `Alt+Tab` / `Alt+Shift+Tab`: window switcher (`io.github.pablo-merino.altswitch`, loaded by `dofile` at the end of `bindings.lua`). Hold Alt and tap Tab; release Alt to switch. It lists windows from every desktop, most recently used first, and leaves out minimized windows. `Alt+Esc` cancels.
- The Surface touchpad has device-specific sensitivity `0.25`; external mouse sensitivity is unaffected.
- Update this table whenever an input or shortcut is added, changed, or removed.
