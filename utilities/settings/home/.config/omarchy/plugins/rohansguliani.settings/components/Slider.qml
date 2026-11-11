// A horizontal slider, 0..maximum. Emits moved(value) while dragging or on
// click, and released(value) once when the press ends; `value` follows the
// source of truth again after release.
import QtQuick
import qs.Commons

Item {
  id: slider
  property real value: 0
  property real maximum: 1
  property bool muted: false
  signal moved(real value)
  signal released(real value)

  implicitWidth: 220
  implicitHeight: 24

  readonly property real shown: drag.pressed ? drag.live : value
  readonly property real fraction: Math.max(0, Math.min(1, shown / maximum))

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 5
    radius: 2.5
    color: Qt.rgba(1, 1, 1, 0.14)
    Rectangle {
      width: Math.max(height, parent.width * slider.fraction)
      height: parent.height
      radius: parent.radius
      color: slider.muted ? Color.muted : Color.accent
    }
  }

  Rectangle {
    width: 16
    height: 16
    radius: 8
    anchors.verticalCenter: parent.verticalCenter
    x: (slider.width - width) * slider.fraction
    color: Color.foreground
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.3)
  }

  MouseArea {
    id: drag
    property real live: 0
    anchors.fill: parent
    anchors.margins: -6
    cursorShape: Qt.PointingHandCursor
    function at(x) { return Math.max(0, Math.min(1, (x - 6) / slider.width)) * slider.maximum }
    onPressed: function(e) { live = at(e.x); slider.moved(live) }
    onPositionChanged: function(e) { if (pressed) { live = at(e.x); slider.moved(live) } }
    onReleased: slider.released(live)
  }
}
