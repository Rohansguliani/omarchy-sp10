import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "SeamLogic.js" as SeamLogic

// Tile-seam drag handles for gapless mode.
//
// Native `resize_on_border` only fires when the pointer is OUTSIDE a window
// box but inside its grab area (InputManager: grab.contains && !real.contains).
// With gaps the two neighboring hover zones sit back-to-back; gapless there is
// no such pixel, so the compositor offers zero zones. This plugin draws the
// missing thing: ONE handle ON each shared tile edge (the seam is implicit —
// two stuck windows share exactly one boundary) and streams relative resizes
// for it while dragged.
//
// Design rules:
// - Event-driven only. Seam bindings re-evaluate on Hyprland rawEvent plus
//   the toplevel/model notifiers they read. No timers, no polling, no
//   per-frame work; idle cost is one static transparent surface per screen.
// - One fullscreen, never-resizing surface per screen (same rationale as the
//   notifications overlay: the compositor never scales a stale buffer).
// - Fixed handle slots (MAX_SEAMS). No dynamic window creation on layout
//   changes; unused slots collapse to 0-size, which contributes no input.
// - Gapless-only: seams are only reported for directly adjacent edges
//   (<=1px). With real gaps, native border-drag owns the interaction and
//   this overlay stays out of the way.
// - Fullscreen workspaces hide all handles (nothing resizable under them).

Item {
  id: root

  // Injected by the host shell (see shell.qml ensureService).
  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  // Bar clearance so a handle strip never eats bar clicks. The bar lives on
  // the Top layer; this overlay is above it, so segments are clamped out of
  // the bar's cross-axis band.
  readonly property string barPosition: (shell && shell.barConfig && typeof shell.barConfig.position === "string")
    ? shell.barConfig.position : "bottom"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property int barClearance: barVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal

  // Bumped on every compositor event so seam bindings re-evaluate even for
  // changes that arrive without a notifier we track directly.
  property int ipcRevision: 0

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.ipcRevision++ }
  }

  // Tiles on one screen: tiled, non-fullscreen windows on the monitor's
  // active workspace, in screen-local logical pixels. Filters read the
  // window's own lastIpcObject (workspace id / monitor id) rather than the
  // resolved .workspace / .monitor object refs, which can lag population
  // and stay null while the IPC payload is already present.
  function normAddress(raw) {
    var a = String(raw || "")
    if (/^0x[0-9a-fA-F]+$/.test(a)) return a
    if (/^[0-9a-fA-F]+$/.test(a)) return "0x" + a
    return ""
  }
  function screenTiles(mon, wsId) {
    var tiles = []
    var all = []
    try {
      all = Hyprland.toplevels.values
    } catch (e) {
      return tiles
    }
    for (var i = 0; i < all.length; i++) {
      var t = all[i]
      if (!t || !t.workspace || t.workspace.id !== wsId) continue
      if (!t.monitor || t.monitor.name !== mon.name) continue
      var ipc = t.lastIpcObject || {}
      if (ipc.floating === true) continue
      if (ipc.fullscreen) continue
      var wfield = ipc.workspace
      var wid = (wfield && typeof wfield === "object") ? wfield.id : wfield
      if (Number(wid) !== wsId) continue
      if (Number(ipc.monitor) !== Number(mon.id)) continue
      var at = ipc.at, size = ipc.size
      if (!at || !size || at.length < 2 || size.length < 2) continue
      var w = Number(size[0]), h = Number(size[1])
      if (!(w > 0) || !(h > 0)) continue
      var addr = root.normAddress(t.address)
      if (!addr) continue
      tiles.push({
        address: addr,
        x: Number(at[0]) - mon.x,
        y: Number(at[1]) - mon.y,
        w: w, h: h
      })
    }
    return tiles
  }

  // Seams for one screen, clamped out of the bar band. Uses the screen's
  // own dimensions (not the overlay window's): the overlay starts invisible
  // at the 100px default window size, so sizing seams from it would
  // deadlock (no size -> no seams -> stays invisible -> never sizes).
  function screenSeams(screen, viewW, viewH) {
    var rev = root.ipcRevision
    if (rev < 0) return []
    var mon = Hyprland.monitorFor(screen)
    if (!mon) return []
    // mon.activeWorkspace can lag behind population; fall back to the
    // focused workspace so handles still resolve. Both are tracked below.
    var ws = mon.activeWorkspace || Hyprland.focusedWorkspace
    if (!ws || ws.hasFullscreen) return []
    if (!(viewW > 0) || !(viewH > 0)) return []
    var tiles = root.screenTiles(mon, ws.id)
    var raw = []
    try {
      raw = SeamLogic.findSeams(tiles)
    } catch (e) {
      console.log("seams: findSeams threw: " + e)
    }
    var out = []
    for (var i = 0; i < raw.length; i++) {
      var s = raw[i]
      if (s.axis === "x") {
        var y0 = Math.max(s.start, root.barPosition === "top" ? root.barClearance : 0)
        var y1 = Math.min(s.end, root.barPosition === "bottom" ? viewH - root.barClearance : viewH)
        if (y1 - y0 >= SeamLogic.MIN_HANDLE) out.push({ axis: "x", pos: s.pos, start: y0, end: y1, first: s.first, second: s.second })
      } else {
        var x0 = Math.max(s.start, root.barPosition === "left" ? root.barClearance : 0)
        var x1 = Math.min(s.end, root.barPosition === "right" ? viewW - root.barClearance : viewW)
        if (x1 - x0 >= SeamLogic.MIN_HANDLE) out.push({ axis: "y", pos: s.pos, start: x0, end: x1, first: s.first, second: s.second })
      }
    }
    return out
  }

  function resizeDispatch(address, dx, dy) {
    if (!/^0x[0-9a-fA-F]+$/.test(String(address || ""))) return
    var x = Math.round(dx), y = Math.round(dy)
    if (x === 0 && y === 0) return
    Hyprland.dispatch('hl.dsp.window.resize({ x = ' + x + ', y = ' + y
      + ', relative = true, window = "address:' + address + '" })')
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      SeamOverlay {
        required property var modelData
        screen: modelData
      }
    }
  }

  component SeamOverlay: PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "rohansguliani-seams"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    ScreenMoveRemap {
      id: remapGuard
      window: win
    }

    readonly property var seams: root.screenSeams(win.screen, win.screen.width, win.screen.height)
    visible: !remapGuard.remapping && seams.length > 0

    // Click-through everywhere except the handle strips.
    mask: Region {
      Region { item: slot0 }
      Region { item: slot1 }
      Region { item: slot2 }
      Region { item: slot3 }
      Region { item: slot4 }
      Region { item: slot5 }
    }

    SeamHandle { id: slot0; seam: win.seams.length > 0 ? win.seams[0] : null }
    SeamHandle { id: slot1; seam: win.seams.length > 1 ? win.seams[1] : null }
    SeamHandle { id: slot2; seam: win.seams.length > 2 ? win.seams[2] : null }
    SeamHandle { id: slot3; seam: win.seams.length > 3 ? win.seams[3] : null }
    SeamHandle { id: slot4; seam: win.seams.length > 4 ? win.seams[4] : null }
    SeamHandle { id: slot5; seam: win.seams.length > 5 ? win.seams[5] : null }
  }

  // One grabbable strip centered on a seam. Idle paints nothing (the cursor
  // flip is the affordance); hover and drag paint a line only. The strip
  // is wider than the visuals for touchpad-friendliness.
  component SeamHandle: Item {
    id: handle

    property var seam: null
    readonly property bool hasSeam: seam !== null && seam !== undefined
    readonly property bool vertical: hasSeam && seam.axis === "x"
    readonly property int hit: 14

    // Model geometry. Frozen for the duration of a drag so the strip doesn't
    // slide out from under the cursor as the seam tracks it.
    readonly property real modelX: !hasSeam ? 0 : (vertical ? seam.pos - hit / 2 : seam.start)
    readonly property real modelY: !hasSeam ? 0 : (vertical ? seam.start : seam.pos - hit / 2)
    readonly property real modelW: !hasSeam ? 0 : (vertical ? hit : seam.end - seam.start)
    readonly property real modelH: !hasSeam ? 0 : (vertical ? seam.end - seam.start : hit)

    property bool dragging: false
    // Hover chrome stays hidden until the pointer re-enters after a drag.
    // Without this, release leaves the cursor sitting on the strip, hover
    // stays true, and the line reads as stuck. entered/exited always
    // re-arm; release disarms.
    property bool revealArmed: true
    readonly property bool showChrome: revealArmed && mouse.containsMouse && !dragging
    readonly property bool showDragLine: revealArmed && dragging
    property real frozenX: 0
    property real frozenY: 0
    property real frozenW: 0
    property real frozenH: 0
    property real pressCursor: 0
    property real lastSent: 0
    property string dragAddr: ""

    x: dragging ? frozenX : modelX
    y: dragging ? frozenY : modelY
    width: dragging ? frozenW : modelW
    height: dragging ? frozenH : modelH
    visible: hasSeam

    function cursorAxisPos(mouse) {
      return handle.vertical ? mouse.x : mouse.y
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: handle.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor

      onPressed: function (ev) {
        if (!handle.hasSeam) return
        handle.dragging = true
        handle.frozenX = handle.modelX
        handle.frozenY = handle.modelY
        handle.frozenW = handle.modelW
        handle.frozenH = handle.modelH
        handle.pressCursor = handle.cursorAxisPos(ev)
        handle.lastSent = 0
        handle.dragAddr = String(handle.seam.first || "")
        ev.accepted = true
      }

      onPositionChanged: function (ev) {
        if (!handle.dragging) return
        // Dragging a vertical seam +dx grows the left window rightward;
        // horizontal +dy grows the top window downward. The compositor
        // moves the shared split 1:1 for the adjacent pair.
        var total = Math.round(handle.cursorAxisPos(ev) - handle.pressCursor)
        var step = total - Math.round(handle.lastSent)
        if (step !== 0 && /^0x[0-9a-fA-F]+$/.test(handle.dragAddr)) {
          if (handle.vertical) root.resizeDispatch(handle.dragAddr, step, 0)
          else root.resizeDispatch(handle.dragAddr, 0, step)
          handle.lastSent = Math.round(handle.lastSent) + step
        }
      }

      onReleased: function () {
        handle.dragging = false
        handle.dragAddr = ""
        handle.revealArmed = false
        root.noteLayoutChanged()
      }
      onCanceled: function () {
        handle.dragging = false
        handle.dragAddr = ""
        handle.revealArmed = false
        root.noteLayoutChanged()
      }
      onEntered: function () { handle.revealArmed = true }
      onExited: function () { handle.revealArmed = true }
    }

    // Highlight line along the seam. Idle: nothing (gapless stays clean;
    // the cursor flip is the affordance). Hover and drag: line only.
    // While dragging it tracks the cursor via dispatched deltas (the seam
    // moves 1:1 with them for the adjacent pair; nested dwindle can drift
    // slightly and snaps to truth on release).
    Rectangle {
      visible: handle.showChrome || handle.showDragLine
      x: handle.vertical
        ? Math.round(parent.width / 2 - 1 + (handle.dragging ? handle.lastSent : 0))
        : 0
      y: handle.vertical
        ? 0
        : Math.round(parent.height / 2 - 1 + (handle.dragging ? handle.lastSent : 0))
      width: handle.vertical ? 2 : parent.width
      height: handle.vertical ? parent.height : 2
      radius: 1
      color: Color.accent
      opacity: handle.dragging ? 0.95 : 0.7
    }
  }
}
