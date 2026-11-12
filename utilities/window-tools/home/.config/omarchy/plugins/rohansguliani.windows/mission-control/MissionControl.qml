// Mission Control: desktops along the top, the current desktop's windows
// spread out below, like macOS. Drawn only; mission-control/mission-control.lua
// sends the snapshot and does the window moves.
//
// Opens and closes instantly, with no animation: it appears in its final
// layout once the window pictures have their first frames.
// Click a window to focus it, click a desktop to go there, drag a window onto
// a desktop (or the new-desktop card / right edge) to move it, hover a desktop
// and click × to close it. Esc or a click on empty space closes Mission Control.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "../shared"

Item {
  id: root

  property var host: null
  property bool opened: false     // capturing and preparing, or on screen
  property bool shown: false      // on screen
  property var snap: ({ current: 1, windows: [] })
  property string dragAddress: ""
  property bool dragging: false
  // Desktop-card reordering: the row index being dragged (-1: none), the
  // index it would land on, and how far it has moved.
  property int reorderFrom: -1
  property int reorderTo: -1
  property real reorderDX: 0
  property bool reorderSettling: false
  // The desktop whose windows the spread shows: the last card hovered, else
  // the current one. Hover a card and move back down to work in it.
  property int previewDesktop: 0
  // True for a moment after a desktop switch, so the new layout appears in
  // place instead of animating to it.
  property bool instant: false
  Timer { id: instantOff; interval: 120; onTriggered: root.instant = false }
  readonly property int shownDesktop: previewDesktop > 0 ? previewDesktop : currentDesktop
  // The spread window under the cursor, if any.
  property string hoveredAddress: ""

  // Stable models, synced from each snapshot by address and desktop id, so
  // an update moves, adds or removes only what changed: thumbnails keep their
  // frames and the rest of the spread slides to its new layout.
  ListModel { id: winModel }   // address, slot, wx, wy, ww, wh, order
  ListModel { id: deskModel }  // desktopId

  // Thumbnails are kept between opens, so Mission Control shows on the same
  // frame it is asked to, with last time's pictures, and they refresh in
  // place. It only waits (up to maxWait) when a window has no picture yet,
  // so it never shows an app icon first.
  readonly property int maxWait: 60
  // Bumped on every open: thumbnails re-resolve their window (an address can
  // be reused by a new window) and grab a fresh frame.
  property int generation: 0
  readonly property int stripHeight: 110
  readonly property int stripTop: 24
  readonly property int gap: 18
  readonly property int currentDesktop: snap.current || 1
  // First workspace id of the focused monitor's block of ten; desktops are
  // labelled 1-10 within it, like the bar does.
  readonly property int firstDesktop: snap.first || 1
  // Monitor name, not a screen object: a screen object dies when its monitor
  // is unplugged or turned off (docking, lid), which destroyed the panel for
  // good. screenFor() reads Quickshell.screens, so the binding below re-runs
  // whenever monitors change and the panel always lands on a live screen.
  property string targetMonitor: ""
  readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"

  function open(data) {
    if (root.opened) return
    if (!data || !Array.isArray(data.windows)) return
    root.snap = data
    root.targetMonitor = data.monitor || ""
    root.dragAddress = ""
    root.dragging = false
    root.syncModels()
    root.generation += 1
    root.shown = false
    root.opened = true
    root.host.lua("windowtools.overview_open = true")
    if (root.thumbsReady()) {
      root.shown = true
    } else {
      readiness.waited = 0
      readiness.restart()
    }
  }

  function thumbsReady() {
    for (var i = 0; i < spreadRepeater.count; i++) {
      var item = spreadRepeater.itemAt(i)
      if (item && item.visible && !item.ready) return false
    }
    return true
  }

  // A new snapshot while open: a window moved to another desktop, or the
  // desktop changed (Ctrl+Left/Right), in which case the spread follows it.
  function update(data) {
    if (root.opened && data && Array.isArray(data.windows)) {
      if (data.current !== root.snap.current) {
        // The desktop changed: show the new one at once, no sliding.
        root.previewDesktop = 0
        root.instant = true
        instantOff.restart()
      }
      root.snap = data
      root.syncModels()
    }
  }

  function syncModels() {
    var list = root.snap.windows || []
    var wanted = ({})
    for (var i = 0; i < list.length; i++) wanted[list[i].address] = true
    for (var r = winModel.count - 1; r >= 0; r--)
      if (!wanted[winModel.get(r).address]) winModel.remove(r)
    for (var j = 0; j < list.length; j++) {
      var w = list[j]
      var row = { address: w.address, slot: w.slot, wx: w.x, wy: w.y, ww: w.w, wh: w.h, order: j }
      var at = -1
      for (var k = 0; k < winModel.count; k++) if (winModel.get(k).address === w.address) { at = k; break }
      if (at < 0) winModel.append(row)
      else winModel.set(at, row)
    }

    // Both sorted; after the removals the model is a subsequence of ids.
    var ids = root.desktops
    for (var d = deskModel.count - 1; d >= 0; d--)
      if (ids.indexOf(deskModel.get(d).desktopId) < 0) deskModel.remove(d)
    for (var n = 0; n < ids.length; n++)
      if (n >= deskModel.count || deskModel.get(n).desktopId !== ids[n]) deskModel.insert(n, { desktopId: ids[n] })
  }

  // address: the window to bring to the front. Hyprland ignores a focus
  // request while this overlay holds the keyboard and then hands focus back to
  // the window that had it, so the overlay goes first and the focus follows.
  function close(address) {
    if (!root.opened) return
    var expression = ""
    var a = address ? root.host.normalAddress(address) : ""
    if (/^0x[0-9a-f]+$/.test(a)) {
      if (root.shownDesktop !== root.currentDesktop)
        expression += "windowtools.goto_desktop(" + (root.shownDesktop - root.firstDesktop + 1) + ") "
      expression += 'windowtools.focus("' + a + '")'
    }
    root.dismiss()
    if (expression) {
      focusAfterClose.expression = expression
      focusAfterClose.restart()
    }
  }

  Timer {
    id: focusAfterClose
    property string expression: ""
    interval: 30
    onTriggered: root.host.lua(expression)
  }

  // Closing with the same key, swipe or mouse button that opened it goes to
  // the window under the cursor, like macOS. Escape and a click on empty space
  // go back to where you were.
  function closeToHovered() {
    var a = root.hoveredAddress
    var showing = a && root.windowsOn(root.shownDesktop).some(function(w) { return w.address === a })
    root.close(showing && !root.dragging ? a : "")
  }

  function dismiss() {
    if (root.opened) root.host.lua("windowtools.overview_open = false")
    readiness.stop()
    root.shown = false
    root.opened = false
    root.dragAddress = ""
    root.dragging = false
    root.cancelReorder()
    root.previewDesktop = 0
    root.hoveredAddress = ""
    // The models (and their thumbnails' pictures) are kept for the next open.
  }

  // Show once every spread thumbnail has a frame, or after maxWait.
  Timer {
    id: readiness
    property int waited: 0
    interval: 4
    repeat: true
    onTriggered: {
      waited += interval
      if (root.thumbsReady() || waited >= root.maxWait) {
        stop()
        root.shown = true
      }
    }
  }

  // Windows on desktop `id` (a workspace id in the focused monitor's block):
  // that slot on every monitor in the snapshot.
  function windowsOn(id) {
    var slot = id - root.firstDesktop + 1
    var out = []
    var list = root.snap.windows || []
    for (var i = 0; i < list.length; i++) if (list[i].slot === slot) out.push(list[i])
    return out
  }

  // The monitors a desktop card draws, and their bounding box, in layout
  // pixels relative to the focused monitor.
  readonly property var monitors: (snap.monitors && snap.monitors.length) ? snap.monitors : [{ name: "", x: 0, y: 0, w: 1440, h: 960 }]
  readonly property var monitorBox: {
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i]
      minX = Math.min(minX, m.x); minY = Math.min(minY, m.y)
      maxX = Math.max(maxX, m.x + m.w); maxY = Math.max(maxY, m.y + m.h)
    }
    return { x: minX, y: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) }
  }

  // Slots (1-10) with windows, on any monitor when desktops are linked.
  readonly property var usedSlots: {
    var used = ({})
    var list = root.snap.used || []
    for (var i = 0; i < list.length; i++) used[list[i]] = true
    return used
  }

  // Workspace ids of the focused monitor for the row: desktops with windows,
  // plus the current one.
  readonly property var desktops: {
    var ids = []
    for (var slot = 1; slot <= 10; slot++) {
      var id = root.firstDesktop + slot - 1
      if (root.usedSlots[slot] || id === root.currentDesktop) ids.push(id)
    }
    return ids
  }

  function closeDesktop(id) {
    var slot = id - root.firstDesktop + 1
    if (slot >= 1 && slot <= 10 && root.desktops.length > 1) root.host.lua("windowtools.close_desktop(" + slot + ")")
  }

  // Where a new desktop goes: the slot after the last desktop in the row, so it
  // appears at the right end; the first gap once slot 10 is taken; -1 if none.
  function firstEmptyDesktop() {
    var last = 0
    for (var s = 1; s <= 10; s++)
      if (root.usedSlots[s] || root.firstDesktop + s - 1 === root.currentDesktop) last = s
    if (last < 10) return root.firstDesktop + last
    for (var slot = 1; slot <= 10; slot++) {
      var id = root.firstDesktop + slot - 1
      if (id !== root.currentDesktop && !root.usedSlots[slot]) return id
    }
    return -1
  }

  function goTo(id) {
    var slot = id - root.firstDesktop + 1
    if (slot >= 1 && slot <= 10) root.host.lua("windowtools.goto_desktop(" + slot + ")")
    root.dismiss()
  }

  // Drop a dragged desktop card. The row updates at once from the local
  // snapshot (thumbnails move to their new cards, the view stays with the
  // current desktop); windowtools.reorder_desktops then moves the windows and
  // sends the real snapshot.
  function finishReorder() {
    var from = root.reorderFrom, to = root.reorderTo
    root.reorderSettling = true
    root.reorderFrom = -1
    root.reorderTo = -1
    root.reorderDX = 0
    Qt.callLater(function() { root.reorderSettling = false })
    if (from < 0 || to < 0 || from === to) return

    var slots = root.desktops.map(function(id) { return id - root.firstDesktop + 1 })
    var moved = slots.splice(from, 1)[0]
    slots.splice(to, 0, moved)
    var positions = slots.slice().sort(function(a, b) { return a - b })
    var dest = ({})
    for (var i = 0; i < slots.length; i++) dest[slots[i]] = positions[i]

    var snap = Object.assign({}, root.snap)
    snap.windows = (root.snap.windows || []).map(function(w) {
      return dest[w.slot] === undefined ? w : Object.assign({}, w, { slot: dest[w.slot] })
    })
    var currentSlot = root.currentDesktop - root.firstDesktop + 1
    if (dest[currentSlot] !== undefined) snap.current = root.firstDesktop + dest[currentSlot] - 1
    // The hovered desktop's windows move too; keep showing them.
    var previewSlot = root.previewDesktop - root.firstDesktop + 1
    if (root.previewDesktop > 0 && dest[previewSlot] !== undefined) root.previewDesktop = root.firstDesktop + dest[previewSlot] - 1
    root.snap = snap
    root.syncModels()
    root.host.lua('windowtools.reorder_desktops("' + slots.join(",") + '")')
  }

  function cancelReorder() {
    root.reorderFrom = -1
    root.reorderTo = -1
    root.reorderDX = 0
  }

  // Move a dragged window to desktop `id` and go there with it. Dropping it
  // back on its own desktop does nothing (it slides home). The overlay closes
  // first: Hyprland ignores focus changes while it holds the keyboard.
  function moveTo(address, id) {
    var a = root.host.normalAddress(address)
    if (!/^0x[0-9a-f]+$/.test(a) || !(id > 0) || id === root.shownDesktop) return
    root.dismiss()
    focusAfterClose.expression = 'windowtools.move_to_slot_and_follow("' + a + '", ' + Math.floor(id - root.firstDesktop + 1) + ')'
    focusAfterClose.restart()
  }

  // Spread layout: the column count that makes the thumbnails largest.
  function layout(items, areaW, areaH) {
    var n = items.length
    if (n === 0) return []
    var label = 24
    var best = null
    for (var cols = 1; cols <= n; cols++) {
      var rows = Math.ceil(n / cols)
      var cellW = (areaW - root.gap * (cols - 1)) / cols
      var cellH = (areaH - root.gap * (rows - 1)) / rows
      var score = 0
      for (var i = 0; i < n; i++) {
        var k = Math.min(cellW / items[i].w, (cellH - label) / items[i].h, 1)
        score += k * k * items[i].w * items[i].h
      }
      if (!best || score > best.score) best = { score: score, cols: cols, rows: rows, cellW: cellW, cellH: cellH }
    }
    var gridH = best.rows * best.cellH + (best.rows - 1) * root.gap
    var out = []
    for (var j = 0; j < n; j++) {
      var col = j % best.cols, row = Math.floor(j / best.cols)
      var rowCount = Math.min(best.cols, n - row * best.cols)
      var rowOffset = (best.cols - rowCount) * (best.cellW + root.gap) / 2
      var scale = Math.min(best.cellW / items[j].w, (best.cellH - label) / items[j].h, 1)
      var w = items[j].w * scale, h = items[j].h * scale
      out.push({
        x: rowOffset + col * (best.cellW + root.gap) + (best.cellW - w) / 2,
        y: (areaH - gridH) / 2 + row * (best.cellH + root.gap) + (best.cellH - label - h) / 2,
        w: w, h: h
      })
    }
    return out
  }

  // Quickshell unmaps a panel whose screen disappears (dock unplugged,
  // monitor or lid off) and never maps it again, which left Mission Control
  // dead until a shell restart. Re-map it on every monitor change.
  Connections {
    target: Quickshell
    function onScreensChanged() { Qt.callLater(function() { panel.visible = false; panel.visible = true }) }
  }

  PanelWindow {
    id: panel
    // Always mapped; parked off-screen while hidden, so opening never waits
    // for a new layer surface.
    visible: true
    screen: root.host.screenFor(root.targetMonitor)
    anchors { top: true; bottom: true; left: true; right: true }
    margins {
      top: root.shown ? 0 : -panel.screenHeight
      bottom: root.shown ? 0 : panel.screenHeight
    }
    readonly property int screenHeight: screen ? screen.height : 2000
    // Width of a desktop card in the row: the shape of every screen the
    // desktop spans (just this one unless desktops are linked).
    readonly property real cardW: Math.min(root.stripHeight * root.monitorBox.w / root.monitorBox.h, panel.width / 4)
    color: "transparent"
    WlrLayershell.namespace: "omarchy-windows-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Backdrop: the wallpaper, dimmed. Loaded once and kept, so it never pops in.
    Image {
      id: backdrop
      anchors.fill: parent
      source: root.wallpaper
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: panel.width * 2
      asynchronous: false
      cache: true
    }
    Rectangle { anchors.fill: parent; color: "black"; visible: backdrop.status !== Image.Ready; z: -1 }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.45) }

    Item {
      anchors.fill: parent
      focus: root.shown
      Keys.onEscapePressed: root.close()
      // Ctrl+Down closes like Ctrl+Up does (to the window under the cursor).
      // Ctrl+Left/Right are Hyprland binds; they switch desktops and the
      // overlay follows (windowtools.desktop_changed).
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Down && (event.modifiers & Qt.ControlModifier)) {
          root.closeToHovered()
          event.accepted = true
        }
      }
      MouseArea { anchors.fill: parent; enabled: root.shown; onClicked: root.close() }
    }

    // Desktop row.
    Row {
      id: strip
      z: 1
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.stripTop
      spacing: root.gap
      // Distance between neighbouring cards.
      readonly property real pitch: panel.cardW + root.gap

      Repeater {
        model: deskModel

        delegate: Item {
          id: desk
          required property int desktopId
          required property int index
          readonly property bool current: desktopId === root.currentDesktop
          readonly property bool lifted: root.reorderFrom === index
          // While a card is dragged: it follows the pointer, and the cards
          // between its old and new place slide over to open a gap.
          readonly property real shift: {
            var from = root.reorderFrom, to = root.reorderTo
            if (from < 0) return 0
            if (lifted) return root.reorderDX
            if (from < to && index > from && index <= to) return -strip.pitch
            if (from > to && index >= to && index < from) return strip.pitch
            return 0
          }
          z: lifted ? 10 : 0
          width: panel.cardW
          height: root.stripHeight + 22
          transform: Translate {
            x: desk.shift
            Behavior on x {
              enabled: !desk.lifted && !root.reorderSettling && !root.instant
              NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
          }

          Rectangle {
            id: deskCard
            width: panel.cardW
            height: root.stripHeight
            radius: Style.cornerRadius
            clip: true
            color: "black"
            // Layout pixels -> card pixels; the arrangement is centred.
            readonly property real k: Math.min(width / root.monitorBox.w, height / root.monitorBox.h)
            readonly property real ox: (width - root.monitorBox.w * k) / 2 - root.monitorBox.x * k
            readonly property real oy: (height - root.monitorBox.h * k) / 2 - root.monitorBox.y * k

            // Each screen's wallpaper (same source and size as the backdrop's
            // texture: no second load), outlined when there are several.
            Repeater {
              model: root.monitors
              delegate: Item {
                required property var modelData
                x: deskCard.ox + modelData.x * deskCard.k
                y: deskCard.oy + modelData.y * deskCard.k
                width: modelData.w * deskCard.k
                height: modelData.h * deskCard.k
                clip: true
                Image {
                  anchors.fill: parent
                  source: root.wallpaper
                  fillMode: Image.PreserveAspectCrop
                  sourceSize.width: panel.width * 2
                  asynchronous: false
                  cache: true
                }
                Rectangle {
                  anchors.fill: parent
                  visible: root.monitors.length > 1
                  color: "transparent"
                  border.width: 1
                  border.color: Qt.rgba(1, 1, 1, 0.14)
                }
              }
            }

            Repeater {
              // Every window has a delegate in every card, shown only in its
              // own desktop's, so a moved window appears in its new card at
              // once with the frame it already has.
              model: winModel
              delegate: WindowThumb {
                required property string address
                required property int slot
                required property real wx
                required property real wy
                required property real ww
                required property real wh
                required property int order
                visible: slot === desk.desktopId - root.firstDesktop + 1
                z: 100 - order  // above the wallpaper; most recent on top
                x: deskCard.ox + wx * deskCard.k
                y: deskCard.oy + wy * deskCard.k
                width: ww * deskCard.k
                height: wh * deskCard.k
                outlined: true
                toplevel: { root.generation; return root.host.toplevelFor(address) }
                live: false
                refreshToken: root.generation
                icon: root.host.appIcon(root.host.classOf(toplevel))
              }
            }

            // Drawn over the wallpaper and thumbnails (a Rectangle's own
            // border sits under its children).
            Rectangle {
              z: 150
              anchors.fill: parent
              radius: parent.radius
              color: "transparent"
              readonly property bool showing: desk.desktopId === root.shownDesktop
              border.width: drop.containsDrag || desk.current || showing || desk.lifted ? 2 : 1
              border.color: drop.containsDrag || desk.lifted ? Color.accent : (showing ? Color.foreground : (desk.current ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.25)))
            }

            // Click: go to the desktop. Press and move sideways: reorder.
            MouseArea {
              id: deskMouse
              anchors.fill: parent
              enabled: root.shown
              hoverEnabled: true
              preventStealing: true
              onContainsMouseChanged: if (containsMouse && root.reorderFrom < 0 && !root.dragging) root.previewDesktop = desk.desktopId
              property real pressX: 0
              property bool reordering: false
              onPressed: function(event) {
                pressX = mapToItem(strip, event.x, event.y).x
                reordering = false
              }
              onPositionChanged: function(event) {
                if (!pressed) return
                // In row coordinates, so the card moving under the pointer
                // doesn't feed back into the distance.
                var dx = mapToItem(strip, event.x, event.y).x - pressX
                if (!reordering) {
                  if (Math.abs(dx) < 8 || root.desktops.length < 2) return
                  reordering = true
                  root.reorderFrom = desk.index
                }
                root.reorderDX = dx
                root.reorderTo = Math.max(0, Math.min(root.desktops.length - 1, Math.round(desk.index + dx / strip.pitch)))
              }
              onReleased: if (reordering) root.finishReorder()
              onCanceled: if (reordering) root.cancelReorder()
              onClicked: if (!reordering) root.goTo(desk.desktopId)
            }
            DropArea {
              id: drop
              anchors.fill: parent
              keys: ["window"]
              onDropped: function(event) { root.moveTo(root.dragAddress, desk.desktopId) }
            }

            // Close: its windows move to the desktop on the left (right if first).
            Rectangle {
              id: closeButton
              z: 200
              visible: root.shown && root.desktops.length > 1 && (deskMouse.containsMouse || closeMouse.containsMouse)
              anchors { top: parent.top; right: parent.right; margins: 4 }
              width: 20; height: 20; radius: 10
              color: closeMouse.containsMouse ? Color.urgent : Qt.rgba(0, 0, 0, 0.75)
              border.color: Qt.rgba(1, 1, 1, 0.4)
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: "×"
                color: "white"
                font.pixelSize: 14
              }
              MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.closeDesktop(desk.desktopId)
              }
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.stripHeight + 4
            text: "Desktop " + (desk.desktopId - root.firstDesktop + 1)
            color: desk.current ? Color.foreground : Color.muted
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.body
          }
        }
      }

      // New desktop. While a window is dragged it opens into a full, empty
      // desktop card; dropping on it, anywhere to its right along the top,
      // or on the screen's right edge puts the window on a new desktop.
      Item {
        id: newDesk
        readonly property bool hot: newDrop.containsDrag || edgeDrop.containsDrag
        visible: root.opened && root.firstEmptyDesktop() > 0
        width: root.dragging ? panel.cardW : root.stripHeight * 0.6
        height: root.stripHeight + 22
        Behavior on width { enabled: !root.instant; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Rectangle {
          width: parent.width
          height: root.stripHeight
          radius: Style.cornerRadius
          color: newDesk.hot ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
          border.width: newDesk.hot ? 2 : 1
          border.color: newDesk.hot ? Color.accent : Qt.rgba(1, 1, 1, 0.2)
          Behavior on color { ColorAnimation { duration: 100 } }

          Text {
            anchors.centerIn: parent
            text: "+"
            color: Color.foreground
            font.pixelSize: Style.font.body * 2
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          y: root.stripHeight + 4
          text: "New Desktop"
          opacity: root.dragging ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 120 } }
          color: newDesk.hot ? Color.foreground : Color.muted
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.body
        }

        MouseArea { anchors.fill: parent; enabled: root.shown; onClicked: root.goTo(root.firstEmptyDesktop()) }
        DropArea {
          id: newDrop
          // From this card to past the screen's right edge, top to row bottom.
          y: -root.stripTop
          width: panel.width
          height: root.stripTop + root.stripHeight + 22 + root.gap
          keys: ["window"]
          onDropped: function(event) { root.moveTo(root.dragAddress, root.firstEmptyDesktop()) }
        }
      }
    }

    // The current desktop's windows, spread out.
    Item {
      id: area
      z: 2
      anchors.fill: parent

      readonly property real spreadTop: root.stripTop + root.stripHeight + 22 + root.gap * 2
      readonly property rect spread: Qt.rect(panel.width * 0.06, spreadTop, panel.width * 0.88, panel.height - spreadTop - root.gap * 2)
      // A window just dropped elsewhere leaves the layout at once.
      readonly property var items: {
        if (!root.opened) return []
        return root.windowsOn(root.shownDesktop)
      }
      readonly property var indexOf: {
        var m = ({})
        for (var i = 0; i < items.length; i++) m[items[i].address] = i
        return m
      }
      readonly property var slots: root.layout(items, spread.width, spread.height)

      // Right screen edge: drop here for a new desktop.
      DropArea {
        id: edgeDrop
        enabled: newDesk.visible
        x: area.spread.x + area.spread.width
        y: area.spread.y
        width: panel.width - x
        height: area.spread.height
        keys: ["window"]
        onDropped: function(event) { root.moveTo(root.dragAddress, root.firstEmptyDesktop()) }
        Rectangle {
          anchors.fill: parent
          anchors.margins: root.gap / 2
          radius: Style.cornerRadius
          visible: root.dragging && newDesk.visible
          color: edgeDrop.containsDrag ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.04)
          border.width: edgeDrop.containsDrag ? 2 : 0
          border.color: Color.accent
          Text {
            anchors.centerIn: parent
            text: "+"
            color: Color.foreground
            opacity: 0.8
            font.pixelSize: Style.font.body * 2
          }
        }
      }

      Text {
        visible: root.opened && area.items.length === 0
        anchors.centerIn: parent
        text: "No windows on this desktop"
        color: Color.muted
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
      }

      Repeater {
        id: spreadRepeater
        model: winModel

        delegate: Item {
          id: slot
          required property string address
          required property real wx
          required property real wy
          required property real ww
          required property real wh
          readonly property int slotIndex: area.indexOf[address] !== undefined ? area.indexOf[address] : -1
          readonly property var to: area.slots[slotIndex] || ({ x: wx - area.spread.x, y: wy - area.spread.y, w: ww, h: wh })
          readonly property bool ready: thumb.hasContent

          visible: slotIndex >= 0
          // A window joining the view (another desktop hovered, a desktop
          // reordered) appears in place; only windows already showing slide
          // when the layout changes.
          property bool placed: false
          onVisibleChanged: if (visible) Qt.callLater(function() { slot.placed = slot.visible }); else placed = false
          x: area.spread.x + to.x
          y: area.spread.y + to.y
          width: to.w
          height: to.h + 24
          Behavior on x { enabled: root.shown && slot.placed && !root.instant; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Behavior on y { enabled: root.shown && slot.placed && !root.instant; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Behavior on width { enabled: root.shown && slot.placed && !root.instant; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Behavior on height { enabled: root.shown && slot.placed && !root.instant; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          // Most recent window on top.
          z: pointer.drag.active ? 1000 : area.items.length - slotIndex

          Item {
            id: tile
            width: slot.width
            height: slot.height
            // The grabbed point stays under the cursor while the window
            // shrinks to about two desktop cards wide.
            property real pressX: width / 2
            property real pressY: 12
            property real s: pointer.drag.active ? Math.min(1, panel.cardW * 2 / Math.max(1, slot.to.w)) : 1
            Behavior on s { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            // Not dropped on another desktop: slide home.
            Behavior on x { enabled: !pointer.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !pointer.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            transform: Scale { origin.x: tile.pressX; origin.y: tile.pressY; xScale: tile.s; yScale: tile.s }
            opacity: pointer.drag.active ? 0.92 : 1
            Drag.active: pointer.drag.active
            Drag.keys: ["window"]
            Drag.hotSpot.x: pressX
            Drag.hotSpot.y: pressY

            Rectangle {
              x: -3; y: -3
              width: slot.to.w + 6
              height: slot.to.h + 6
              radius: Style.cornerRadius
              color: "transparent"
              border.width: 2
              border.color: root.shown && (pointer.containsMouse || pointer.drag.active) ? Color.accent : "transparent"
            }

            WindowThumb {
              id: thumb
              width: slot.to.w
              height: slot.to.h
              toplevel: { root.generation; return root.host.toplevelFor(slot.address) }
              outlined: true
              // Every window keeps its last frame, even while Mission Control
              // is closed, so nothing waits on a first capture or shows an app
              // icon; only the ones on view stream, and only while shown.
              live: root.shown && slot.visible
              refreshToken: root.generation
              icon: root.host.appIcon(root.host.classOf(toplevel))
            }

            Text {
              y: slot.to.h + 6
              width: slot.to.w
              opacity: pointer.drag.active ? 0 : 1
              horizontalAlignment: Text.AlignHCenter
              text: thumb.toplevel ? (thumb.toplevel.title || "") : ""
              elide: Text.ElideRight
              textFormat: Text.PlainText
              color: Color.foreground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.body
            }
          }

          MouseArea {
            id: pointer
            anchors.fill: parent
            enabled: root.shown
            hoverEnabled: true
            drag.target: tile
            drag.threshold: 8
            drag.onActiveChanged: root.dragging = drag.active
            onContainsMouseChanged: {
              if (containsMouse) root.hoveredAddress = slot.address
              else if (root.hoveredAddress === slot.address) root.hoveredAddress = ""
            }
            onPressed: function(event) {
              root.dragAddress = slot.address
              tile.pressX = event.x
              tile.pressY = event.y
            }
            onReleased: {
              if (tile.Drag.target) tile.Drag.drop()
              tile.x = 0
              tile.y = 0
            }
            onClicked: root.close(slot.address)
          }
        }
      }
    }
  }
}
