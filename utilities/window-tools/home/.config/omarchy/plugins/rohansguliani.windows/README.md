# Window tools for Omarchy

Small window utilities, one folder each. Every tool binds its own keys and
gestures; the shell plugin draws the two panels.

| Folder | What | Keys and gestures |
|---|---|---|
| `desktops/` | Desktops 1-10, linked across monitors, empty ones skipped | Super+1..0, Super+Shift+1..0, Ctrl+Shift+1..0, Ctrl+Left/Right, four-finger left/right, Super+Alt+D |
| `window-actions/` | Maximize, half-screen snap and width steps for floating windows; border-drag resizing (`edge-resize.lua`: sides change one axis, corners both, a window sharing the dragged side follows); Helium's tab-row buttons | Alt+A / Ctrl+Shift+A, Alt+Left/Right, Alt+=/-, drag a border |
| `edge-snap/` | Drag a window to a screen's left/right edge to snap it to that half, with a preview | drag |
| `switcher/` | Alt+Tab with live thumbnails, current desktop only | Alt+Tab, Alt+Shift+Tab, Alt+Esc |
| `mission-control/` | Desktops on top, this desktop's windows below; drag to move, drag a desktop card sideways to reorder, × to close a desktop | four-finger up/down, Ctrl+Up |
| `shared/` | `core.lua` (find/focus windows, talk to the shell) and `WindowThumb.qml` (window picture with icon fallback) | |

`Windows.qml` is the shell plugin entry: it hosts `switcher/Switcher.qml` and
`mission-control/MissionControl.qml`. `load.lua` loads every Lua tool.
`desktops/` and `window-actions/` need no shell plugin; Mission Control needs
`desktops/`.

## Install

```bash
# folder: ~/.config/omarchy/plugins/rohansguliani.windows
omarchy plugin enable rohansguliani.windows
```

From any Hyprland Lua config file (on this machine,
`~/.config/hypr/utilities/window-tools.lua`), all tools:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/load.lua")
```

or one tool, for example:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/rohansguliani.windows/window-actions/window-actions.lua")
```

Then `hyprctl reload`.

## Why maximize is emulated

Hyprland's maximize is a fullscreen mode: one window per workspace, and
focusing or opening another window there removes it. On floating desktops
`window-actions.lua` instead resizes the window to the monitor's work area and
remembers its old geometry, so it stays a normal floating window.
`~/.config/default/hypr/workspace-modes.lua` points Omarchy's titlebar □ and
double-click at it.

## Behaviour

- **Alt+Tab**: hold Alt, tap Tab (Shift+Tab back), release to switch. Most
  recently used first. The selected thumbnail is live, the rest are one
  captured frame. A quick tap switches without drawing.
- **Mission Control**: opens and closes instantly. Click a window to focus it,
  click a desktop to go there, drag a window onto a desktop, the new-desktop
  card or the right edge to move it. Esc or a click on empty space closes it.
- **Snap**: Alt+Left/Right halves; the same key again restores.
- **Width**: Alt+= (or Alt++) widens, Alt+- narrows, 5% of the screen per press (hold to repeat). A window touching the edge that moves follows it, so the border between two snapped halves moves for both.
- **Drag to an edge** (`edge-snap/`): drag a floating window until the cursor touches a screen's left or right edge; an outline shows the half, and dropping snaps it there (Alt+Left/Right then restores the size it had before the drag). Hyprland has no drag events and titlebar drags never reach binds, so a light timer (40 ms idle, 16 ms while dragging) watches the active window move with the cursor. A Super+drag or Helium tab-row drag snaps on release; a titlebar drag snaps as soon as the window stops following the cursor, which is the first mouse movement after the drop.

## Scripting

```bash
hyprctl eval 'windowtools.maximize("0x...")'
hyprctl eval 'windowtools.snap("left")'
hyprctl eval 'windowtools.goto_desktop(3)'
omarchy-shell windows overviewOpen | overviewClose | overviewToggle | state
```

After editing any QML here, run `omarchy restart shell`: Omarchy's hot reload
leaves the panels unmapped until then.
