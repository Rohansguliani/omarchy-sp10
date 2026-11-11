// A settings page: title row, then the page's groups in a scrolling column
// that stays a readable width on wide windows. Set `backLabel` for a
// "‹ Back" link above the title (a detail view); it emits back().
import QtQuick
import QtQuick.Controls
import qs.Commons

Flickable {
  id: page
  property string title: ""
  property string backLabel: ""
  signal back()
  default property alias content: body.data
  property alias headerRight: headerRight.data

  contentHeight: body.implicitHeight + 56
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  Column {
    id: body
    x: Math.max(28, (page.width - width) / 2)
    y: 28
    width: Math.min(page.width - 56, 680)
    spacing: 22

    Label {
      visible: page.backLabel !== ""
      height: visible ? implicitHeight : 0
      text: "‹  " + page.backLabel
      color: backMouse.containsMouse ? Color.foreground : Color.accent
      MouseArea {
        id: backMouse
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: page.back()
      }
    }

    Item {
      width: parent.width
      height: 34
      Label {
        anchors.verticalCenter: parent.verticalCenter
        text: page.title
        font.pixelSize: Style.font.title + 4
        font.weight: Font.DemiBold
      }
      Row {
        id: headerRight
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 12
      }
    }
  }
}
