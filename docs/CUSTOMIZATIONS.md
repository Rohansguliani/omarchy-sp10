# Active Customizations

## Touchpad

File:

```text
~/.config/hypr/input.lua
```

Active override:

```lua
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      drag_3fg = 1,
    },
  },
  gestures = {
    workspace_swipe_cancel_ratio = 0.25,
    workspace_swipe_forever = true,
  },
})

hl.device({ name = "microsoft-surface-045e:09af-touchpad", sensitivity = 0.25 })

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

for workspace = 1, 10 do
  hl.workspace_rule({ workspace = tostring(workspace), persistent = true })
end
```

Natural scrolling and three-finger drag are enabled. The Surface touchpad uses `0.25` sensitivity without changing the speed of an external mouse. Three fingers perform a left-click-and-drag, allowing text selection and dragging files, tabs, and other draggable interface elements without holding down the touchpad. Four-finger horizontal swipes switch workspaces instantly, with no sliding animation: one swipe moves exactly one workspace (fingers left = next), firing as soon as the fingers travel `SWIPE_TRIGGER` (40) units rather than on lift. It stops at workspaces 1 and 10. Workspaces 1–10 are persistent, so empty workspaces remain valid swipe destinations.

## Workspace switching shortcuts

File:

```text
~/.config/hypr/bindings.lua
```

Active bindings:

```lua
o.bind("CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
```

`Ctrl+Right` switches to the next workspace and `Ctrl+Left` switches to the previous workspace. These are global Hyprland bindings, so applications no longer receive those key combinations for word-by-word cursor movement.

## Alt+1 area screenshot to clipboard

File:

```text
~/.config/hypr/bindings.lua
```

Active binding:

```lua
o.bind("ALT + 1", "Area screenshot to clipboard", "omarchy-capture-screenshot region copy")
```

This opens the region selector and copies the selected image directly to the clipboard without requiring a saved file.

## Auto-hiding top bar

Files:

```text
~/.config/omarchy/shell.json
~/.config/omarchy/plugins/rohansguliani.bar/Bar.qml
```

The active bar is a cloned user plugin, `rohansguliani.bar`, based on `omarchy.bar`. It auto-hides by default, reveals only when the cursor touches the topmost pixel of the screen, remains visible while the cursor is within the bar or one of its popups, and hides immediately when the cursor leaves. Its opaque background covers the content beneath it, and it always uses `ExclusionMode.Ignore` so shown/hidden bar state overlays existing windows instead of resizing tiled windows.

### Reloading bar changes

Plugin rescans do not reliably recreate the bar surface, so changes can appear ineffective or behave like an older version. After every edit to `rohansguliani.bar`, validate it and fully restart Omarchy Shell:

```bash
OMARCHY_PATH=/usr/share/omarchy omarchy plugin validate ~/.config/omarchy/plugins/rohansguliani.bar
OMARCHY_PATH=/usr/share/omarchy omarchy restart shell
```

Confirm the restarted shell and plugin are healthy:

```bash
OMARCHY_PATH=/usr/share/omarchy omarchy-shell shell ping
OMARCHY_PATH=/usr/share/omarchy omarchy-shell shell listPlugins | jq -r '.[] | select(.id=="rohansguliani.bar") | if .error then .error else "plugin ok" end'
```

Do not rely on `omarchy-shell shell rescanPlugins` alone for bar behavior changes.

## Compact tiled-window grid

File:

```text
~/.config/hypr/looknfeel.lua
```

Active override:

```lua
hl.config({
  general = {
    gaps_in = 2,
    border_size = 1,
    col = {
      active_border = "#333333",
      inactive_border = "#1f1f1f",
    },
  },
})
```

The normal tiled layout uses a 2-pixel inner gap and subdued 1-pixel borders instead of Omarchy's brighter 5-pixel gap and 2-pixel border. `Super+Shift+Backspace` still toggles the completely gapless, borderless layout.

## Screensaver disabled

Files:

```text
~/.config/omarchy/shell.json
~/.config/hypr/hypridle.conf
```

Omarchy shell idle has `screensaver` set to `2147483` seconds, the largest practical Qt timer interval. The Hypridle fallback no longer launches `omarchy-launch-screensaver`; it only locks after 5 minutes and wakes the display on resume.

## Ctrl+Alt+S suspend

File:

```text
~/.config/hypr/bindings.lua
```

Active binding:

```lua
o.bind("CTRL + ALT + S", "Suspend", "systemctl suspend")
```

This suspends the machine through systemd.

## Lid and Surface suspend policy

System policy:

```text
/etc/systemd/logind.conf.d/lid-policy.conf
```

Closing the lid suspends on battery. On external power or while docked, the system stays awake; `~/.local/bin/omarchy-lid-power-policy` turns off the internal display until the lid opens.

Surface Pro 10 suspend workarounds:

```text
/etc/limine-entry-tool.d/surface-pro-10.conf
/etc/systemd/system-sleep/surface-power-button-only-wake
/etc/systemd/system/surface-buttons.service
```

The boot configuration disables i915 PSR2 selective fetch. During s2idle, only the physical Surface power button remains wake-enabled, and `soc_button_array` reloads at boot for reliable power-button wake. These settings are active: the kernel command line contains `i915.enable_psr2_sel_fetch=0`, and `surface-buttons.service` is enabled and active.

## Omarchy lock reload hotfix

Retired 2026-11-03: Omarchy 4.0.6 fixes this upstream (`keepLoaded` services survive plugin rescans). The hook and script are in `/root/mux-removed-2026-11-03/`.

The source patch is also kept in `~/omarchy` on branch `fix/preserve-lock-during-plugin-reload`.

## Built-in display and power profile

File:

```text
~/.config/hypr/monitors.lua
```

The built-in `eDP-1` panel is explicitly configured for 2880×1920 at 120 Hz with scale 2. Omarchy's native `power-profiles-daemon` backend is enabled and active, and the currently selected profile is `performance`. The GPU is not pinned; the broken `omarchy-max-gpu-performance.service` was removed. `surface-sp10-pl4.service` raises the firmware PL4 limit instead (see `SYSTEM.md`).

## Helium desktop shortcut

Files:

```text
~/.config/omarchy/plugins/local.helium-desktop/manifest.json
~/.config/omarchy/plugins/local.helium-desktop/DesktopShortcut.qml
~/.config/omarchy/shell.json
```

A user-level Omarchy service plugin shows a **Helium Browser** shortcut near the upper-left of every display on the Wayland bottom layer. Clicking it runs `uwsm-app -- helium-browser --new-window`, so the new browser window opens on the current workspace. The plugin uses current Omarchy `Util.alpha(...)` helpers and is enabled in `shell.json`.

## Camera stack

The built-in Surface Pro 10 cameras require a custom kernel, patched libcamera packages, and a WirePlumber rule. The full setup and its calibration limitations are documented in [`CAMERA.md`](CAMERA.md).

## Obsidian Black theme

User theme location:

```text
~/.config/omarchy/themes/obsidian-black/
```

Important files:

```text
colors.toml
icons.theme
backgrounds/black.png
preview.png
```

Apply it with:

```bash
omarchy theme set obsidian-black
```

The theme uses pure black (`#000000`) for the main, dark, and darker backgrounds; near-black for raised surfaces; grayscale accents; and a solid-black 3840×2160 wallpaper.

Omarchy generates themed configurations for its shell, terminals, btop, Neovim, Helix, VS Code, Obsidian, and Chromium-family browsers from `colors.toml`.

### Helium theme and title bar

Helium (and Chromium) read `/etc/chromium/policies/managed/`. Omarchy's `color.json` there sets `BrowserThemeColor`, which overrides the installed "Into The Black Hole" AMOLED theme extension and makes Chromium generate its own gray palette (gray address bar, active tab and extension pill). The file was removed on 2026-09-11, recreated by the 4.5 update or `omarchy theme set`, and removed again on 2026-11-03 (moved to `/root/mux-removed-2026-11-03/chromium-color.json`). If Helium turns gray again:

```bash
sudo rm /etc/chromium/policies/managed/color.json
helium-browser --refresh-platform-policy --no-startup-window
```

On floating workspaces Helium has no Omarchy titlebar. It draws its own maximize and close buttons at the end of its tab row (`browser.custom_chrome_frame` = true; `gsettings org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'`). Other apps keep the Omarchy titlebar, slimmed to 24 px.

Helium's own maximize button can't work here. Hyprland tells every window it is maximized, so after one click Helium waits for a "restored" state that never arrives and stops sending requests (seen in a `WAYLAND_DEBUG` trace). Omarchy also ignores app maximize requests. A full tab row also leaves Helium no empty space to drag. So `~/.config/hypr/hyprland.lua` handles both with a non-consuming left-click bind (`mouse:272`, `mouse = true`) on Helium's top 30 px, measured from the window's right edge:

| From right edge | Action |
|---|---|
| 28–55 px (Helium's ⧉ button) | toggle maximize |
| 55–80 px (Helium's − button) | minimize to the dock (`omarchy-hyprland-window-minimize`) |
| 82–165 px (+, extensions, menu) | press and drag moves the window; a plain click still reaches Helium |
| double-click, from max(400 px, 40% of width) to 165 px from the right (tabs and the empty space after them) | toggle maximize; the address bar on the left is excluded |

After a drag, a 50 ms timer brings the window back on screen if the tab row ended up above the screen. If the drag started maximized, it also clamps the window horizontally. The bind runs on every press, and on release only after it started a drag; `helium_dragging` skips that release call. If Helium's button layout or sizes change, re-measure these offsets. Helium reads the button layout only at startup. `Super`+drag still works anywhere.

`~/.config/default/hypr/workspace-modes.lua` shadows Omarchy's module of the same name. It loads Omarchy's file and removes only the `unmaximize_others(window)` call, so opening a window no longer un-maximizes the others on a floating workspace. If upstream changes that line, the override falls back to Omarchy's original and shows a critical notification.

## Old Hyprland backup

The pre-reset configuration was preserved at:

```text
~/.config/hypr.pre-omarchy-defaults-20260831-213037
```

The active configuration is under `~/.config/hypr/` and was migrated to Quattro’s Lua format.
