// Displays: drag to arrange monitors (they snap edge to edge), and pick
// resolution, refresh rate, scale and rotation for the selected one.
//
// Changes apply live with `hyprctl eval 'hl.monitor(...)'`. Arranging is
// saved at once; resolution, refresh, scale and rotation ask "Keep these
// settings?" and revert by themselves after 15 s (or when you leave the page),
// in case the new mode leaves a screen unreadable. Saving rewrites only the
// managed block in ~/.config/hypr/monitors.lua (bin/displays-save).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "../components"
import "Layout.js" as Layout

Page {
  id: root
  title: "Displays"

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/rohansguliani.settings/bin/displays-save"
  readonly property int confirmSeconds: 15

  // Enabled displays: what Hyprland reports, and edited in place by the page.
  // { name, label, description, internal, modes, w, h, rate, scale, transform, x, y }
  property var monitors: []
  property var offNames: []
  property string selectedName: ""
  readonly property var selected: root.find(root.monitors, root.selectedName)
  // Set while a mode/scale/rotation change waits for Keep: the state to go back to.
  property var revertTo: null
  property int countdown: 0

  Component.onDestruction: if (root.revertTo) root.revert()

  function find(list, name) {
    for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i]
    return null
  }

  function clone(list) { return JSON.parse(JSON.stringify(list)) }

  // "3840x2160@60.00Hz" -> modes, best rate first within a resolution.
  function parseModes(available, w, h, rate) {
    var seen = ({}), out = []
    var all = (available || []).concat([w + "x" + h + "@" + rate + "Hz"])
    for (var i = 0; i < all.length; i++) {
      var m = /^(\d+)x(\d+)@([\d.]+)/.exec(String(all[i]))
      if (!m) continue
      var mode = { w: Number(m[1]), h: Number(m[2]), rate: Number(Number(m[3]).toFixed(2)) }
      var key = mode.w + "x" + mode.h + "@" + mode.rate
      if (seen[key]) continue
      seen[key] = true
      out.push(mode)
    }
    out.sort(function(a, b) { return b.w * b.h - a.w * a.h || b.rate - a.rate })
    return out
  }

  function load(text) {
    var list
    try { list = JSON.parse(text) } catch (error) { list = [] }
    var mons = [], off = []
    for (var i = 0; i < list.length; i++) {
      var m = list[i]
      if (m.name === "FALLBACK") continue
      var name = String(m.make || "") + " " + String(m.model || "")
      if (m.disabled) { off.push(name.trim() || m.name); continue }
      var internal = /^(eDP|LVDS|DSI)-/.test(m.name)
      // "Lenovo Group Limited" + "T32UD-40" -> "Lenovo T32UD-40".
      var brand = String(m.make || "").split(" ")[0]
      var model = String(m.model || "")
      // "Sceptre Tech Inc" + "Sceptre C35" -> "Sceptre C35", not "Sceptre Sceptre C35".
      var shortName = (model.indexOf(brand) === 0 ? model : brand + " " + model).trim()
      mons.push({
        name: m.name,
        label: internal ? "Built-in Display" : (shortName || m.description || m.name),
        description: String(m.description || ""),
        internal: internal,
        modes: root.parseModes(m.availableModes, m.width, m.height, m.refreshRate),
        w: m.width, h: m.height, rate: Number(Number(m.refreshRate).toFixed(2)),
        scale: m.scale, transform: m.transform, x: m.x, y: m.y, focused: m.focused
      })
    }
    mons.sort(function(a, b) { return a.x - b.x || a.y - b.y })
    root.monitors = mons
    root.offNames = off
    if (!root.find(mons, root.selectedName)) {
      var pick = mons.filter(function(m) { return m.focused })[0] || mons[0]
      root.selectedName = pick ? pick.name : ""
    }
  }

  function rectsOf(list) {
    return list.map(function(m) {
      var size = Layout.logical(m)
      return { name: m.name, x: m.x, y: m.y, w: size.w, h: size.h }
    })
  }

  function luaString(value) { return '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"' }
  function outputOf(m) { return m.internal || !m.description ? m.name : "desc:" + m.description }
  function modeText(m) { return m.w + "x" + m.h + "@" + m.rate }

  function applyLive(list) {
    var rules = list.map(function(m) {
      return "hl.monitor({ output = " + root.luaString(root.outputOf(m)) +
        ", mode = " + root.luaString(root.modeText(m)) +
        ", position = " + root.luaString(m.x + "x" + m.y) +
        ", scale = " + Layout.scaleText(m.scale) +
        ", transform = " + m.transform + " })"
    })
    Quickshell.execDetached(["hyprctl", "eval", rules.join("; ")])
    reread.restart()
  }

  function save(list) {
    var rules = list.map(function(m) {
      return { output: root.outputOf(m), mode: root.modeText(m), position: m.x + "x" + m.y,
               scale: Layout.scaleText(m.scale), transform: m.transform }
    })
    Quickshell.execDetached([root.helper, JSON.stringify(rules)])
  }

  // Resolution, refresh, scale or rotation: apply now, keep the arrangement
  // touching, and ask before saving.
  function change(name, fields) {
    var before = root.clone(root.monitors)
    var list = root.clone(root.monitors)
    var m = root.find(list, name)
    if (!m) return
    for (var key in fields) m[key] = fields[key]
    if (fields.w !== undefined) m.scale = Layout.cleanScale(m.scale, m.w, m.h)
    // The largest other display stays put; this one re-snaps beside it.
    var anchor = m
    for (var i = 0; i < list.length; i++) {
      var o = list[i]
      if (o.name !== name && (anchor === m || o.w * o.h > anchor.w * anchor.h)) anchor = o
    }
    var placed = Layout.arrange(root.rectsOf(list), anchor.name)
    for (var j = 0; j < placed.length; j++) {
      var target = root.find(list, placed[j].name)
      target.x = placed[j].x
      target.y = placed[j].y
    }
    root.monitors = list
    root.applyLive(list)
    if (!root.revertTo) root.revertTo = before
    root.countdown = root.confirmSeconds
    confirmTimer.restart()
  }

  function keep() {
    confirmTimer.stop()
    root.revertTo = null
    root.save(root.monitors)
  }

  function revert() {
    if (!root.revertTo) return
    confirmTimer.stop()
    root.monitors = root.revertTo
    root.revertTo = null
    root.applyLive(root.monitors)
  }

  // Arranging: snap beside the others, move the top-left to 0,0, apply, save.
  function moveDisplay(name, lx, ly) {
    var list = root.clone(root.monitors)
    var m = root.find(list, name)
    if (!m) return
    var size = Layout.logical(m)
    var others = root.rectsOf(list.filter(function(o) { return o.name !== name }))
    var p = Layout.snap({ x: lx, y: ly, w: size.w, h: size.h }, others)
    m.x = p.x
    m.y = p.y
    var minX = Infinity, minY = Infinity
    for (var i = 0; i < list.length; i++) { minX = Math.min(minX, list[i].x); minY = Math.min(minY, list[i].y) }
    for (var k = 0; k < list.length; k++) { list[k].x -= minX; list[k].y -= minY }
    root.monitors = list
    root.applyLive(list)
    root.save(list)
  }

  // Unique resolutions, largest first; then refresh rates for one.
  function resolutions(m) {
    var seen = ({}), out = []
    for (var i = 0; i < m.modes.length; i++) {
      var key = m.modes[i].w + "x" + m.modes[i].h
      if (seen[key]) continue
      seen[key] = true
      out.push({ value: { w: m.modes[i].w, h: m.modes[i].h },
                 label: m.modes[i].w + " × " + m.modes[i].h + (out.length === 0 ? "   (native)" : "") })
    }
    return out
  }

  function rates(m) {
    return m.modes.filter(function(mode) { return mode.w === m.w && mode.h === m.h })
      .map(function(mode) { return { value: mode.rate, label: mode.rate + " Hz" } })
  }

  function pickResolution(m, res) {
    var best = null
    for (var i = 0; i < m.modes.length; i++) {
      var mode = m.modes[i]
      if (mode.w !== res.w || mode.h !== res.h) continue
      if (mode.rate === m.rate) { best = mode; break }
      if (!best) best = mode
    }
    if (best) root.change(m.name, { w: best.w, h: best.h, rate: best.rate })
  }

  Process {
    id: query
    running: true
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.load(text)
    }
  }

  // Read back what Hyprland actually applied (it may adjust a scale).
  Timer { id: reread; interval: 400; onTriggered: query.running = true }

  Timer {
    id: confirmTimer
    interval: 1000
    repeat: true
    onTriggered: {
      root.countdown -= 1
      if (root.countdown <= 0) root.revert()
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (/^monitor(added|removed)/.test(event.name)) reread.restart()
    }
  }

  // --- Small controls -------------------------------------------------------

  component Chip: Rectangle {
    id: chip
    property string label: ""
    property bool active: false
    signal picked()
    implicitWidth: chipText.implicitWidth + 24
    height: 32
    radius: Math.min(8, Style.cornerRadius + 6)
    color: active ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
                  : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04))
    border.width: 1
    border.color: active ? Color.accent : Qt.rgba(1, 1, 1, 0.16)
    Label {
      id: chipText
      anchors.centerIn: parent
      text: chip.label
      color: chip.active ? Color.foreground : Color.muted
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: !root.revertTo
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.picked()
    }
  }

  component Dropdown: Rectangle {
    id: dropdown
    property string label: ""
    property var options: []
    property var choose: null
    width: 300
    height: 32
    radius: Math.min(8, Style.cornerRadius + 6)
    color: dropMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
    border.width: 1
    border.color: popup.anchorItem === dropdown ? Color.accent : Qt.rgba(1, 1, 1, 0.16)
    Label {
      anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
      text: dropdown.label
    }
    Label {
      anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
      text: "⌄"
      color: Color.muted
    }
    MouseArea {
      id: dropMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: !root.revertTo && dropdown.options.length > 1
      cursorShape: Qt.PointingHandCursor
      onClicked: popup.anchorItem === dropdown ? popup.close() : popup.openFor(dropdown, dropdown.options, dropdown.choose)
    }
  }

  // --- Layout ---------------------------------------------------------------

  // Keep / revert, at the top so it can't be missed.
  Rectangle {
    width: parent.width
    height: 52
    visible: root.revertTo !== null
    radius: Math.min(10, Style.cornerRadius + 6)
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
    border.width: 1
    border.color: Color.accent

    Label {
      anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
      text: "Keep these display settings?  Reverting in " + root.countdown + " s"
    }
    Row {
      anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
      spacing: 8
      PillButton { text: "Revert"; onClicked: root.revert() }
      PillButton { text: "Keep"; primary: true; onClicked: root.keep() }
    }
  }

  // Arrangement.
  Rectangle {
    id: canvas
    width: parent.width
    height: 300
    radius: Math.min(10, Style.cornerRadius + 8)
    color: Qt.rgba(1, 1, 1, 0.035)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    readonly property var rects: root.rectsOf(root.monitors)
    readonly property var box: {
      var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
      for (var i = 0; i < rects.length; i++) {
        minX = Math.min(minX, rects[i].x); minY = Math.min(minY, rects[i].y)
        maxX = Math.max(maxX, rects[i].x + rects[i].w); maxY = Math.max(maxY, rects[i].y + rects[i].h)
      }
      return rects.length ? { x: minX, y: minY, w: maxX - minX, h: maxY - minY } : { x: 0, y: 0, w: 1, h: 1 }
    }
    // Room to drag a display beside the others.
    readonly property real k: Math.min((width - 80) / (box.w * 1.15), (height - 40) / (box.h * 1.15))
    readonly property real ox: (width - box.w * k) / 2 - box.x * k
    readonly property real oy: (height - box.h * k) / 2 - box.y * k

    Repeater {
      model: root.monitors

      delegate: Rectangle {
        id: tile
        required property var modelData
        readonly property var size: Layout.logical(modelData)
        readonly property bool isSelected: modelData.name === root.selectedName
        property real dx: 0
        property real dy: 0
        property bool dragging: false

        x: canvas.ox + modelData.x * canvas.k + dx
        y: canvas.oy + modelData.y * canvas.k + dy
        width: size.w * canvas.k
        height: size.h * canvas.k
        z: dragging ? 10 : 1
        radius: 6
        color: isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.20) : Qt.rgba(1, 1, 1, 0.08)
        border.width: isSelected ? 2 : 1
        border.color: isSelected ? Color.accent : Qt.rgba(1, 1, 1, 0.3)
        opacity: dragging ? 0.85 : 1

        Column {
          anchors.centerIn: parent
          width: parent.width - 12
          spacing: 2
          Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.modelData.label
            font.pixelSize: Style.font.bodySmall
          }
          // The real resolution, as in the Resolution menu; the tile's size is
          // what it looks like (resolution ÷ scale), which is how the pointer
          // moves between displays.
          Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.modelData.w + " × " + tile.modelData.h
            color: Color.muted
            font.pixelSize: Style.font.caption
          }
          Label {
            visible: Math.abs(tile.modelData.scale - 1) > 0.005
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: "looks like " + tile.size.w + " × " + tile.size.h
            color: Color.muted
            font.pixelSize: Style.font.caption
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: !root.revertTo
          cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          // Dragging a tile must not scroll the page.
          preventStealing: true
          property point start
          onPressed: function(event) {
            start = mapToItem(canvas, event.x, event.y)
            root.selectedName = tile.modelData.name
            popup.close()
          }
          onPositionChanged: function(event) {
            if (root.monitors.length < 2) return
            var p = mapToItem(canvas, event.x, event.y)
            if (!tile.dragging && Math.abs(p.x - start.x) + Math.abs(p.y - start.y) < 4) return
            tile.dragging = true
            tile.dx = p.x - start.x
            tile.dy = p.y - start.y
          }
          onReleased: {
            if (!tile.dragging) return
            var lx = tile.modelData.x + tile.dx / canvas.k
            var ly = tile.modelData.y + tile.dy / canvas.k
            tile.dragging = false
            tile.dx = 0
            tile.dy = 0
            root.moveDisplay(tile.modelData.name, lx, ly)
          }
        }
      }
    }
  }

  Label {
    text: root.monitors.length > 1 ? "Drag displays to arrange them. Click one to change its settings."
                                   : "Connect another display to arrange displays."
    color: Color.muted
    font.pixelSize: Style.font.caption
  }

  // Settings for the selected display.
  Group {
    visible: root.selected !== null
    title: root.selected ? root.selected.label + (root.selected.description ? "  ·  " + root.selected.description : "") : ""

    GroupRow {
      title: "Resolution"
      Dropdown {
        label: root.selected ? root.selected.w + " × " + root.selected.h : ""
        options: root.selected ? root.resolutions(root.selected) : []
        choose: function(value) { root.pickResolution(root.selected, value) }
      }
    }
    GroupRow {
      title: "Refresh rate"
      Dropdown {
        label: root.selected ? root.selected.rate + " Hz" : ""
        options: root.selected ? root.rates(root.selected) : []
        choose: function(value) { root.change(root.selected.name, { rate: value }) }
      }
    }
    GroupRow {
      title: "Scale"
      subtitle: {
        if (!root.selected) return ""
        var size = Layout.logical(root.selected)
        return "Looks like " + size.w + " × " + size.h + (root.selected.scale >= 1.5 ? "  ·  larger text" : "  ·  more space")
      }
      below: [
        Flow {
          width: parent.width
          spacing: 6
          Repeater {
            model: root.selected ? Layout.scaleOptions(root.selected.w, root.selected.h) : []
            delegate: Chip {
              required property var modelData
              label: Number(modelData.scale.toFixed(2)) + "×"
              active: root.selected && Math.abs(root.selected.scale - modelData.scale) < 0.005
              onPicked: root.change(root.selected.name, { scale: modelData.scale })
            }
          }
        }
      ]
    }
    GroupRow {
      title: "Rotation"
      Repeater {
        model: [{ value: 0, label: "Standard" }, { value: 1, label: "90°" }, { value: 2, label: "180°" }, { value: 3, label: "270°" }]
        delegate: Chip {
          required property var modelData
          label: modelData.label
          active: root.selected && root.selected.transform === modelData.value
          onPicked: root.change(root.selected.name, { transform: modelData.value })
        }
      }
    }
  }

  Label {
    visible: root.offNames.length > 0
    text: "Turned off: " + root.offNames.join(", ")
    color: Color.muted
    font.pixelSize: Style.font.caption
  }

  // Shared option list for the dropdowns, above the page content.
  Rectangle {
    id: popup
    // Declared here, but lives on the scrolling content above the page column.
    Component.onCompleted: parent = root.contentItem
    property var anchorItem: null
    property var options: []
    property var choose: null
    visible: anchorItem !== null
    z: 100
    width: anchorItem ? anchorItem.width : 0
    height: Math.min(list.contentHeight + 8, 300)
    radius: Math.min(8, Style.cornerRadius + 6)
    color: Color.background
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.2)

    function openFor(item, options, choose) {
      var p = item.mapToItem(root.contentItem, 0, item.height + 4)
      popup.x = p.x
      popup.y = p.y
      popup.options = options
      popup.choose = choose
      popup.anchorItem = item
    }
    function close() { popup.anchorItem = null }

    ListView {
      id: list
      anchors.fill: parent
      anchors.margins: 4
      clip: true
      model: popup.options
      boundsBehavior: Flickable.StopAtBounds
      delegate: Rectangle {
        required property var modelData
        width: list.width
        height: 30
        radius: 6
        color: optionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        Label {
          anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
          text: modelData.label
        }
        MouseArea {
          id: optionMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            var choose = popup.choose
            popup.close()
            if (choose) choose(modelData.value)
          }
        }
      }
    }
  }
}
