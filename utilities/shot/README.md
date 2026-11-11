# shot

Area screenshots, OCR, and a quick annotate-and-copy editor. A port of
[rohanMacUtils' `shot`](https://github.com/Rohansguliani/rohanMacUtils/tree/main/macos27/shot),
same hotkeys with Alt for Opt.

| Hotkey | Does |
|---|---|
| **Alt+1** | drag an area → PNG on the clipboard |
| **Alt+2** | drag an area → its text on the clipboard (tesseract, on-device) |
| **Alt+`** | the **last** Alt+1 / Alt+2 capture in the editor (nothing yet → a selection that opens the editor) |

While selecting: **Esc** or right-click cancels; a selection under 2×2 cancels.
The screen under the cursor is frozen at the keypress, and the selection is cut
from that frame, so a playing video or the dimming can't end up in the shot. No
labels or hints are drawn.

## Editor

Opens over the spot the shot came from (centred if it is too big to fit at 1:1).
Drag the toolbar to move it.

| Key | Tool | | Key | Action |
|---|---|---|---|---|
| **A** | arrow | | **Ctrl+C** | copy annotated image and close |
| **R** | box | | **Ctrl+S** | save PNG to ~/Pictures and close |
| **P** | pen (default) | | **Ctrl+Z** | undo |
| **T** | text: click, type, Return | | **Esc** / **Ctrl+W** | close |
| **B** | pixelate an area | | | |

Capture hotkeys still work with it open (Alt+1 closes it and starts a new capture).

## Files

| File | Role |
|---|---|
| `home/.local/bin/shotd` | the resident GTK4 daemon (selection overlay, crop, OCR, editor) |
| `home/.local/bin/shot` | `shot copy|ocr|edit [monitor]`: writes the command to `$XDG_RUNTIME_DIR/shot.fifo`, starting the service if needed |
| `home/.config/systemd/user/shot.service` | runs `shotd` in the graphical session |
| `home/.config/hypr/utilities/shot.lua` | the three hotkeys, no animation on the overlay, the editor window rule |

Options (`SAVE_DIR`, `OCR_LANG`, `COLOR`, `STROKE`) are constants at the top of
`shotd`. Its log has the timings: `journalctl --user -u shot`.

## Speed

Hotkey → frozen overlay on screen: 90–150 ms on the 4K monitor, almost all of it
`grim` copying the 3840×2160 frame (60–100 ms by itself). Mouse-up → PNG on the
clipboard is a crop plus a PNG encode. OCR is a tesseract run, about half a
second for a few lines.

Not ported from the Mac version: enlarging the editor window for drawing room
around the shot.
