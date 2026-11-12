# awui-shell

The bar, its menus and the Settings window, rewritten in Rust on
[AntiWebUI](https://github.com/bea4dev/AntiWebUI) instead of Omarchy's
Quickshell. One program, `omarchy-awui`, runs as a user service.

| Piece | What it does |
|---|---|
| Bar | Bottom bar that shows when the pointer touches the bottom edge: the current desktop's windows (click to focus, click the focused one to minimize), sound, battery, clock |
| Sound menu | Volume, output device, apps playing (folded), Sound Settings… |
| Battery menu | Charge, state, power mode, Battery Settings… |
| Settings | Wi-Fi (connected, previously connected, other networks), Bluetooth (connected, previously connected, nearby), Sound, Displays, Devices, Battery, About |

Colors come from the current Omarchy theme and follow theme changes.

`omarchy-awui msg settings <page>` opens Settings (`omarchy-settings-open`
wraps it); `omarchy-awui msg toggle sound|battery` opens a bar menu.

Omarchy still draws the lock screen, notifications, Spotlight, Alt+Tab and
Mission Control. Its own bar is replaced by the empty `omarchy-awui.nobar`
plugin; the old QML Settings, Sound and Taskbar plugins are disabled in
`shell.json`.

`setup.sh` builds the crate (`cargo build --release --locked`) when its source
is newer than `~/.local/bin/omarchy-awui`. Undo: `systemctl --user disable --now
omarchy-awui`, set `bar.id` in `shell.json` back, re-enable the old plugins.
