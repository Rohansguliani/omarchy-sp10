// A small rounded button. `primary` fills it with the accent colour.
import QtQuick
import qs.Commons

Rectangle {
  id: button
  property string text: ""
  property bool primary: false
  property bool busy: false
  property bool danger: false
  signal clicked()

  implicitWidth: label.implicitWidth + 26
  implicitHeight: 30
  radius: Math.min(8, Style.cornerRadius + 6)
  color: primary ? (mouse.containsMouse ? Qt.lighter(Color.accent, 1.12) : Color.accent)
                 : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
  border.width: primary ? 0 : 1
  border.color: Qt.rgba(1, 1, 1, 0.12)
  opacity: busy ? 0.55 : 1

  Label {
    id: label
    anchors.centerIn: parent
    text: button.text
    color: button.primary ? Color.background : (button.danger ? Color.urgent : Color.foreground)
    font.weight: button.primary ? Font.DemiBold : Font.Normal
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: !button.busy
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
