// A titled, rounded group of rows (GroupRow), like a macOS settings section.
// `empty` shows a muted line in the box when there are no rows.
import QtQuick
import qs.Commons

Column {
  id: group
  property string title: ""
  property string note: ""
  property string empty: ""
  property bool showEmpty: false
  default property alias rows: inner.data
  property alias titleRight: titleRight.data

  width: parent ? parent.width : 0
  spacing: 8

  Item {
    visible: group.title !== ""
    width: parent.width
    height: 20
    Label {
      x: 4
      anchors.verticalCenter: parent.verticalCenter
      text: group.title
      color: Color.muted
      font.weight: Font.DemiBold
    }
    Row {
      id: titleRight
      anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
      spacing: 8
    }
  }

  Rectangle {
    width: parent.width
    height: group.showEmpty ? 48 : inner.implicitHeight
    radius: Math.min(10, Style.cornerRadius + 8)
    color: Qt.rgba(1, 1, 1, 0.035)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)
    clip: true

    Column {
      id: inner
      width: parent.width
      visible: !group.showEmpty
    }
    Label {
      visible: group.showEmpty
      x: 14
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 28
      elide: Text.ElideRight
      text: group.empty
      color: Color.muted
    }
  }

  Label {
    visible: group.note !== ""
    x: 4
    width: parent.width - 8
    wrapMode: Text.WordWrap
    text: group.note
    color: Color.muted
    font.pixelSize: Style.font.caption
  }
}
