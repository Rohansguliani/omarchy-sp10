// Edge-snap preview: a translucent outline of the half a dragged window will
// snap to. Drawn only; edge-snap/edge-snap.lua decides when and where.
// Pointer input passes through (empty mask), so the drag is never disturbed.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var host: null
  property string monitor: ""
  property rect target: Qt.rect(0, 0, 0, 0)
  property bool shown: false

  function show(data) {
    if (!data) return
    root.monitor = String(data.monitor || "")
    root.target = Qt.rect(Number(data.x) || 0, Number(data.y) || 0, Number(data.w) || 0, Number(data.h) || 0)
    root.shown = root.target.width > 0 && root.target.height > 0
  }

  function hide() {
    root.shown = false
  }

  PanelWindow {
    visible: root.shown
    screen: root.host.screenFor(root.monitor)
    anchors { top: true; left: true }
    margins { top: root.target.y; left: root.target.x }
    implicitWidth: root.target.width
    implicitHeight: root.target.height
    color: "transparent"
    WlrLayershell.namespace: "omarchy-windows-edge-snap"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    Rectangle {
      anchors.fill: parent
      anchors.margins: 8
      radius: Style.cornerRadius
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16)
      border.width: 2
      border.color: Color.accent
    }
  }
}
