// An on/off switch.
import QtQuick
import qs.Commons

Rectangle {
  id: sw
  property bool checked: false
  property bool busy: false
  signal toggled()

  implicitWidth: 42
  implicitHeight: 24
  radius: height / 2
  color: checked ? Color.accent : Qt.rgba(1, 1, 1, 0.18)
  opacity: busy ? 0.6 : 1

  Rectangle {
    width: 18
    height: 18
    radius: 9
    y: 3
    x: sw.checked ? sw.width - width - 3 : 3
    color: sw.checked ? Color.background : Color.foreground
    Behavior on x { NumberAnimation { duration: 90 } }
  }

  MouseArea {
    anchors.fill: parent
    enabled: !sw.busy
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled()
  }
}
