# Tile Seams (`rohansguliani.seams`)

One drag handle **on** each shared tile edge, for gapless mode. Idle paints
nothing — hovering a seam flips the cursor and shows a thin highlight line;
dragging moves the boundary with a tracking line. No pills, no badges.

Native `resize_on_border` only fires when the pointer is outside a window box
but inside its grab area. Gapless there is no such pixel, so this overlay
draws the missing control: a hover/drag highlight line centered on every
directly adjacent tile seam. Dragging a vertical seam `+dx` grows the left window
rightward (`hl.dsp.window.resize`, relative); horizontal `+dy` grows the top
window downward. The compositor moves the shared split 1:1 for the pair.

## Behavior

- Gapless-only: seams need a shared edge within 1px. With real gaps the
  overlay reports nothing and native border-drag owns the interaction.
- Event-driven: recomputes on Hyprland IPC events plus the toplevel/model
  notifiers. No timers, no polling. Idle cost is one static transparent
  surface per screen.
- One fullscreen, never-resizing surface per screen; 6 fixed handle slots
  (unused slots collapse to 0-size and take no input). Segments shorter
  than 96px (`MIN_HANDLE` in `SeamLogic.js`) get no handle.
- Hidden on workspaces with a fullscreen window. Segments are clamped out
  of the bar band so strips never eat bar clicks.
- Hit strip is 14px wide centered on the seam; the only visual is a 2px
  line on hover/drag. Touchpad-friendly by design, invisible otherwise.

## Known limits

- 3+ window dwindle trees: one handle per seam segment, but moving it walks
  the BSP tree, so a third window can shift — same quirk as native resize.
- More than 6 seams on one screen: extras get no handle (raise slot count
  in `Seams.qml` if you ever hit this).
- `SeamLogic.js` is dependency-free on purpose: `node /tmp/seamtest.mjs`
  covers 2-split, 3-col, L-shape, gaps, slivers, and ordering.

## Disable

Remove `{ "id": "rohansguliani.seams" }` from `~/.config/omarchy/shell.json`
`plugins`, then `omarchy restart shell` (unlocked session only).
