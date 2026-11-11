// One row in a Group: optional icon, title and subtitle on the left, the
// row's controls (children) on the right. A hairline separates it from the
// row above. `expanded` content (e.g. a password field) goes in `below`.
// With `editable`, double-clicking the title edits it in place: Enter emits
// renamed(text), Esc or clicking away cancels.
import QtQuick
import qs.Commons

Item {
  id: row
  property string icon: ""
  property string title: ""
  property string subtitle: ""
  property color subtitleColor: Color.muted
  property bool dim: false
  property bool clickable: false
  property bool editable: false
  property bool editing: false
  default property alias trailing: right.data
  property alias below: belowBox.data
  signal clicked()
  signal renamed(string text)

  function startEdit() {
    if (!row.editable) return
    editor.text = row.title
    row.editing = true
    editor.forceActiveFocus()
    editor.selectAll()
  }
  function finishEdit(save) {
    if (!row.editing) return
    row.editing = false
    var t = editor.text.trim()
    if (save && t !== "" && t !== row.title) row.renamed(t)
  }

  width: parent ? parent.width : 0
  implicitHeight: top.height + (belowBox.childrenRect.height > 0 ? belowBox.childrenRect.height + 12 : 0)

  Rectangle {
    anchors.fill: parent
    color: row.clickable && hover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
  }

  Rectangle {
    visible: row.y > 0
    anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 14 }
    height: 1
    color: Qt.rgba(1, 1, 1, 0.07)
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: row.clickable
    enabled: row.clickable
    cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: row.clicked()
  }

  Item {
    id: top
    width: parent.width
    height: Math.max(50, texts.implicitHeight + 20)

    Label {
      id: iconLabel
      visible: row.icon !== ""
      anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
      width: 22
      horizontalAlignment: Text.AlignHCenter
      text: row.icon
      font.pixelSize: Style.font.icon
      opacity: row.dim ? 0.5 : 1
    }

    Column {
      id: texts
      anchors {
        left: row.icon !== "" ? iconLabel.right : parent.left
        leftMargin: row.icon !== "" ? 12 : 14
        right: right.left
        rightMargin: 12
        verticalCenter: parent.verticalCenter
      }
      spacing: 2
      Label {
        id: titleLabel
        visible: !row.editing
        width: parent.width
        elide: Text.ElideRight
        text: row.title
        opacity: row.dim ? 0.6 : 1

        MouseArea {
          visible: row.editable
          width: Math.min(parent.width, titleLabel.implicitWidth)
          height: parent.height
          cursorShape: Qt.IBeamCursor
          onDoubleClicked: row.startEdit()
        }
      }
      Rectangle {
        visible: row.editing
        width: parent.width
        height: titleLabel.height + 6
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.06)
        border.color: Color.accent
        border.width: 1

        TextInput {
          id: editor
          anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
          verticalAlignment: TextInput.AlignVCenter
          color: Color.foreground
          selectionColor: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          maximumLength: 64
          clip: true
          Keys.onReturnPressed: row.finishEdit(true)
          Keys.onEnterPressed: row.finishEdit(true)
          Keys.onEscapePressed: function(event) { event.accepted = true; row.finishEdit(false) }
          onActiveFocusChanged: if (!activeFocus) row.finishEdit(false)
        }
      }
      Label {
        visible: row.subtitle !== ""
        width: parent.width
        elide: Text.ElideRight
        text: row.subtitle
        color: row.subtitleColor
        font.pixelSize: Style.font.caption
      }
    }

    Row {
      id: right
      anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
      spacing: 8
    }
  }

  Item {
    id: belowBox
    anchors { top: top.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 12 }
    implicitHeight: childrenRect.height
  }
}
