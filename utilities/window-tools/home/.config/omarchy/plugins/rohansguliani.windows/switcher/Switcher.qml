// Alt+Tab panel: a row of window thumbnails, the selected one live.
// Drawn only; switcher/switcher.lua owns keys and state. It appears after a
// short delay so a quick Alt+Tab tap switches without the panel ever drawing.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "../shared"

Item {
  id: root

  property var host: null
  property var windows: []
  property int selectedIndex: 0
  property bool requested: false
  property bool shown: false
  // The focused monitor's name; the panel moves there when Alt+Tab starts.
  // A name, not a screen object, so the panel survives monitors being
  // unplugged or turned off (see MissionControl.qml).
  property string targetMonitor: ""

  readonly property int thumbHeight: 150
  readonly property int labelHeight: 26
  readonly property int pad: 8

  function show(payload) {
    watchdog.restart()
    if (!payload || !Array.isArray(payload.windows)) { root.hide(); return }
    root.windows = payload.windows
    root.selectedIndex = payload.index || 0
    root.targetMonitor = payload.monitor || ""
    root.requested = root.windows.length > 0
    if (root.requested) { reveal.waited = 0; reveal.restart() }
  }

  function select(index) {
    root.selectedIndex = index
    watchdog.restart()
  }

  function hide() {
    reveal.stop()
    watchdog.stop()
    root.requested = false
    root.shown = false
    root.windows = []
  }

  function thumbWidth(w, h) {
    var aspect = h > 0 ? w / h : 1.5
    return Math.round(Math.max(110, Math.min(300, root.thumbHeight * aspect)))
  }

  // Thumbnails start capturing as soon as Alt+Tab is pressed, while the panel
  // is still parked off-screen. It appears once every thumbnail has a frame,
  // so no app icon placeholder flashes first, but never before minDelay (a
  // quick tap switches without the panel drawing) and never later than
  // maxDelay (a window that can't be captured shows its icon).
  Timer {
    id: reveal
    readonly property int minDelay: 70
    readonly property int maxDelay: 250
    property int waited: 0
    interval: 8
    repeat: true
    onTriggered: {
      waited += interval
      if (!root.requested) { stop(); return }
      if (waited < minDelay) return
      var ready = true
      for (var i = 0; i < cards.count; i++) {
        var card = cards.itemAt(i)
        if (card && !card.ready) { ready = false; break }
      }
      if (ready || waited >= maxDelay) {
        stop()
        root.shown = true
      }
    }
  }

  // If an Alt release is ever missed, give up and reset the Lua side too.
  Timer {
    id: watchdog
    interval: 10000
    onTriggered: { root.hide(); root.host.lua("windowtools.switcher_cancel()") }
  }

  // Re-map after monitor changes; see the same block in MissionControl.qml.
  Connections {
    target: Quickshell
    function onScreensChanged() { Qt.callLater(function() { panel.visible = false; panel.visible = true }) }
  }

  PanelWindow {
    id: panel
    // Always mapped; parked off-screen while hidden. Creating the layer
    // surface on every Alt+Tab would cost a few frames before it can draw.
    visible: true
    screen: root.host.screenFor(root.targetMonitor)
    anchors { top: true; bottom: true; left: true; right: true }
    margins {
      top: root.shown ? 0 : -panel.screenHeight
      bottom: root.shown ? 0 : panel.screenHeight
    }
    readonly property int screenHeight: screen ? screen.height : 2000
    color: "transparent"
    WlrLayershell.namespace: "omarchy-windows-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // Never grab the keyboard: Alt and Tab must keep reaching Hyprland.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
      MouseArea { anchors.fill: parent; onClicked: root.host.lua("windowtools.switcher_cancel()") }
    }

    Rectangle {
      anchors.centerIn: parent
      width: flow.width + root.pad * 2
      height: flow.implicitHeight + root.pad * 2
      radius: Style.cornerRadius
      color: Color.menu.background
      border.color: Color.menu.border
      border.width: 1

      Flow {
        id: flow
        anchors.centerIn: parent
        width: Math.min(totalWidth, panel.width * 0.9)
        spacing: root.pad
        readonly property real totalWidth: {
          var total = 0
          for (var i = 0; i < root.windows.length; i++)
            total += root.thumbWidth(root.windows[i].w, root.windows[i].h) + root.pad * 2 + (i > 0 ? root.pad : 0)
          return total
        }

        Repeater {
          id: cards
          model: root.windows

          delegate: Rectangle {
            id: card
            required property var modelData
            required property int index
            readonly property bool selected: index === root.selectedIndex
            readonly property var toplevel: root.host.toplevelFor(modelData.address)
            readonly property bool ready: thumb.hasContent

            width: root.thumbWidth(modelData.w, modelData.h) + root.pad * 2
            height: root.thumbHeight + root.labelHeight + root.pad * 2
            radius: Style.cornerRadius
            color: selected ? Color.menu.selectedBackground : "transparent"
            border.color: selected ? Color.accent : "transparent"
            border.width: 2

            WindowThumb {
              id: thumb
              x: root.pad; y: root.pad
              width: parent.width - root.pad * 2
              height: root.thumbHeight
              toplevel: card.toplevel
              live: card.selected
              capturing: root.requested
              icon: root.host.appIcon(card.modelData.appClass)
            }

            Row {
              x: root.pad
              y: root.pad + root.thumbHeight + 4
              width: parent.width - root.pad * 2
              spacing: 6
              Image {
                width: 16; height: 16
                anchors.verticalCenter: parent.verticalCenter
                sourceSize.width: 32; sourceSize.height: 32
                source: root.host.appIcon(card.modelData.appClass)
                asynchronous: true
              }
              Text {
                width: parent.width - 22
                anchors.verticalCenter: parent.verticalCenter
                text: card.modelData.title
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: card.selected ? Color.menu.selectedText : Color.menu.text
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.body
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.host.lua("windowtools.switcher_pick(" + card.index + ")")
            }
          }
        }
      }
    }
  }
}
