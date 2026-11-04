import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.Commons
import qs.Ui

Item {
  id: root

  function launchHeliumWindow() {
    Util.execArgv(["uwsm-app", "--", "helium-browser", "--new-window"])
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: shortcutWindow
      required property var modelData

      screen: modelData
      visible: !remapGuard.remapping
      implicitWidth: shortcut.width
      implicitHeight: shortcut.height
      anchors {
        top: true
        left: true
      }
      margins {
        top: Style.space(38)
        left: Style.space(18)
      }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.namespace: "helium-desktop-shortcut"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      ScreenMoveRemap {
        id: remapGuard
        window: shortcutWindow
      }

      Item {
        id: shortcut
        width: Style.space(92)
        height: Style.space(112)

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: mouseArea.containsMouse || mouseArea.pressed
            ? Util.alpha(Color.background, mouseArea.pressed ? 0.82 : 0.64)
            : "transparent"
          border.width: mouseArea.containsMouse ? 1 : 0
          border.color: Util.alpha(Color.foreground, 0.28)

          Behavior on color {
            ColorAnimation { duration: 100 }
          }
        }

        Image {
          id: icon
          width: Style.space(64)
          height: width
          anchors {
            top: parent.top
            topMargin: Style.space(8)
            horizontalCenter: parent.horizontalCenter
          }
          source: Quickshell.iconPath("helium-browser", true)
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          mipmap: true
        }

        Text {
          anchors {
            top: icon.bottom
            topMargin: Style.space(5)
            left: parent.left
            right: parent.right
          }
          text: "Helium Browser"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.Medium
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          style: Text.Outline
          styleColor: Util.alpha(Color.background, 0.9)
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton
          onClicked: root.launchHeliumWindow()
        }
      }
    }
  }
}
