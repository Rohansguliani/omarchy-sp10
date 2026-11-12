// A window's live picture, with its app icon until the first frame arrives.
// Shared by the switcher and Mission Control.
//
// live: true streams frames; false captures one frame when shown, which is all
// a small, unselected thumbnail needs.

import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root

  property var toplevel: null      // HyprlandToplevel
  property bool live: false
  property bool capturing: true    // false releases the capture entirely
  property string icon: ""
  // A faint frame, so a dark window still reads against a dark wallpaper.
  property bool outlined: false
  // Change it to grab a fresh frame (for a thumbnail that isn't live).
  property int refreshToken: 0
  onRefreshTokenChanged: if (!root.live && view.captureSource) view.captureFrame()
  readonly property bool hasContent: view.hasContent

  readonly property var source: capturing && toplevel ? toplevel.wayland : null

  ScreencopyView {
    id: view
    anchors.fill: parent
    captureSource: root.source
    live: root.live
    paintCursor: false
    visible: hasContent
    onCaptureSourceChanged: if (captureSource && !root.live) Qt.callLater(view.captureFrame)
  }

  Image {
    visible: !view.hasContent && root.icon !== ""
    anchors.centerIn: parent
    width: Math.min(parent.width, parent.height) * 0.4
    height: width
    sourceSize.width: width * 2
    sourceSize.height: height * 2
    source: root.icon
    fillMode: Image.PreserveAspectFit
    asynchronous: true
  }

  Rectangle {
    anchors.fill: parent
    visible: root.outlined
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.22)
  }
}
