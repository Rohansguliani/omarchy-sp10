# window-tools

The `rohansguliani.windows` shell plugin: macOS-style window handling. Its own
README (`home/.config/omarchy/plugins/rohansguliani.windows/README.md`) covers
each tool:

| Folder | Does |
|---|---|
| `desktops/` | desktop switching (Super+N, Ctrl+Left/Right, four-finger swipe), linked across monitors, empty desktops skipped, new desktop past the end |
| `window-actions/` | maximize that survives new windows (Alt+A), Alt+Left/Right snap, Alt+=/- width with a linked neighbour, Helium tab-row buttons; `window-memory.lua`: each floating window remembers its place per monitor (by model), so undocking keeps it at the same relative spot (maximized/snapped stay so) and re-docking puts it back exactly |
| `edge-snap/` | drag a window to a screen's left/right edge to snap it to that half, with a preview |
| `switcher/` | Alt+Tab with live thumbnails, current desktop only |
| `mission-control/` | Ctrl+Up / four-finger up: desktops on top, windows below, drag windows between desktops, drag desktop cards to reorder. While open, Ctrl+Left/Right switch desktops and it follows; Ctrl+Down (or Ctrl+Up) closes |
| `shared/` | helpers and the window thumbnail every tool uses |

All bindings are keysyms, so they work on any keyboard.

| Other file | Role |
|---|---|
| `home/.config/hypr/utilities/window-tools.lua` | loads the plugin's Hyprland half |
| `home/.config/default/hypr/workspace-modes.lua` | Omarchy's floating mode minus "un-maximize others when a window opens" |
