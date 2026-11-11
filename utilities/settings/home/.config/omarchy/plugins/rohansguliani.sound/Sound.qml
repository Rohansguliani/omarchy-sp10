// Sound menu for the bar, like macOS: one volume slider, the output devices
// with a check on the current one, "Apps" to open per-app volumes in place,
// and "Sound Settings…" for everything else (input, the full mixer).
//
// The bar icon: click opens the menu, scroll changes volume, right-click
// mutes. Volume and mute from the icon go through Omarchy's
// omarchy-audio-output-volume, so its on-screen display still shows.
//
// Rows hold node ids, never PwNode objects: PipeWire deletes nodes outright
// and a delegate still holding one can crash the shell.

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "rohansguliani.sound"
  ipcTarget: "rohansguliani.sound"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var outputs: nodes.filter(function(n) { return n && n.isSink && !n.isStream })
  readonly property var apps: nodes.filter(function(n) {
    return n && n.isStream && n.isSink && String(n.name || "").indexOf("omarchy_speaker_tuning") !== 0
  })

  PwObjectTracker { objects: [root.sink].concat(root.opened ? root.outputs.concat(root.apps) : []) }

  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
  property bool showApps: false
  property real wheelAccumulator: 0

  onOpenedChanged: if (!opened) showApps = false

  function node(id) {
    for (var i = 0; i < root.nodes.length; i++) if (root.nodes[i] && root.nodes[i].id === id) return root.nodes[i]
    return null
  }
  function ids(list) { return list.map(function(n) { return n.id }) }

  function deviceLabel(n) {
    if (!n) return ""
    var t = String(n.description || n.nickname || n.name || "Unknown")
    t = t.replace(/ (Analog|Digital) Stereo.*$| Pro( \d+)?$/, "")
    // "HP USB-C Universal Docking Station" -> "HP Dock".
    t = t.replace(/ (USB-C |Thunderbolt )?(Universal )?Dock(ing Station)?( G\d)?$/i, " Dock")
    if (/^Built-in Audio$/.test(t) || /alsa_output\.pci/.test(String(n.name))) return "Speakers"
    return t
  }
  function appLabel(n) {
    if (!n) return ""
    var p = n.ready && n.properties ? n.properties : {}
    return String(p["application.name"] || n.description || p["media.name"] || n.name || "App")
  }
  function isHeadphones(n) {
    return !!n && /bluez|headphone|headset|airpods/i.test(String(n.name) + " " + root.deviceLabel(n))
  }
  function deviceIcon(n) {
    if (root.isHeadphones(n)) return "󰋋"
    if (/hdmi|displayport|dock|monitor/i.test(String(n.name) + " " + root.deviceLabel(n))) return "󰍹"
    return "󰓃"
  }
  function barIcon() {
    if (!root.sink || root.muted) return "󰖁"
    if (root.isHeadphones(root.sink)) return "󰋋"
    if (root.volume < 0.01) return "󰕿"
    return root.volume < 0.5 ? "󰖀" : "󰕾"
  }

  function setVolume(v) {
    if (!root.sink || !root.sink.audio) return
    root.sink.audio.muted = false
    root.sink.audio.volume = Math.max(0, Math.min(1, v))
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barIcon()
    onPressed: function(b) {
      if (b === Qt.RightButton) Quickshell.execDetached(["omarchy-audio-output-volume", "mute-toggle"])
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps !== 0) Quickshell.execDetached(["omarchy-audio-output-volume", (wheel.steps > 0 ? "+" : "-") + Math.abs(wheel.steps * 5)])
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: Style.space(300)
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(560))

    content: PanelKeyCatcher {
      implicitHeight: menu.implicitHeight
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: menu
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: "Sound"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.weight: Font.DemiBold
        }

        // Volume.
        Row {
          width: parent.width
          height: Style.space(30)
          spacing: Style.space(10)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "󰖁" : "󰕿"
            color: Color.muted
            font.pixelSize: Style.font.icon
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: Quickshell.execDetached(["omarchy-audio-output-volume", "mute-toggle"]) }
          }
          Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(30) * 2 - Style.space(20)
            value: root.volume
            dim: root.muted
            onMoved: function(v) { root.setVolume(v) }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰕾"
            color: Color.muted
            font.pixelSize: Style.font.icon
          }
        }

        Separator {}

        Heading { text: "Output" }
        Repeater {
          model: root.ids(root.outputs)
          delegate: MenuRow {
            id: outRow
            required property var modelData
            readonly property var n: root.node(modelData)
            readonly property bool current: root.sink !== null && n !== null && root.sink.id === n.id
            icon: n ? root.deviceIcon(n) : ""
            label: root.deviceLabel(n)
            checked: current
            onClicked: if (n && !current) Pipewire.preferredDefaultAudioSink = n
          }
        }

        Separator {}

        MenuRow {
          icon: "󰝚"
          label: root.apps.length > 0 ? "Apps  ·  " + root.apps.length : "Apps"
          trailing: root.showApps ? "⌄" : "›"
          onClicked: root.showApps = !root.showApps
        }
        Text {
          visible: root.showApps && root.apps.length === 0
          leftPadding: Style.space(34)
          text: "No apps are playing sound"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Repeater {
          model: root.showApps ? root.ids(root.apps) : []
          delegate: Column {
            id: appRow
            required property var modelData
            readonly property var n: root.node(modelData)
            width: menu.width
            leftPadding: Style.space(34)
            spacing: Style.space(2)
            Text {
              width: parent.width - parent.leftPadding
              elide: Text.ElideRight
              text: root.appLabel(appRow.n)
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Slider {
              width: parent.width - parent.leftPadding - Style.space(8)
              value: appRow.n && appRow.n.audio ? appRow.n.audio.volume : 0
              dim: appRow.n && appRow.n.audio ? appRow.n.audio.muted : false
              onMoved: function(v) {
                var x = root.node(appRow.modelData)
                if (x && x.audio) { x.audio.muted = false; x.audio.volume = Math.max(0, Math.min(1, v)) }
              }
            }
          }
        }

        MenuRow {
          label: "Sound Settings…"
          onClicked: {
            root.close()
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/omarchy/plugins/rohansguliani.settings/bin/settings-open", "sound"])
          }
        }
      }
    }
  }

  component Heading: Text {
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.weight: Font.DemiBold
  }

  component Separator: Rectangle {
    width: parent ? parent.width : 0
    height: 1
    color: Qt.rgba(1, 1, 1, 0.08)
  }

  component MenuRow: Rectangle {
    id: row
    property string icon: ""
    property string label: ""
    property string trailing: ""
    property bool checked: false
    signal clicked()
    width: parent ? parent.width : 0
    height: Style.space(30)
    radius: Math.min(6, Style.cornerRadius + 4)
    color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    Text {
      id: rowIcon
      visible: row.icon !== ""
      anchors { left: parent.left; leftMargin: Style.space(6); verticalCenter: parent.verticalCenter }
      width: Style.space(20)
      horizontalAlignment: Text.AlignHCenter
      text: row.icon
      color: row.checked ? Color.accent : Color.popups.text
      font.pixelSize: Style.font.icon
    }
    Text {
      anchors {
        left: row.icon !== "" ? rowIcon.right : parent.left
        leftMargin: row.icon !== "" ? Style.space(8) : Style.space(6)
        right: rowEnd.left
        rightMargin: Style.space(6)
        verticalCenter: parent.verticalCenter
      }
      elide: Text.ElideRight
      text: row.label
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    Text {
      id: rowEnd
      anchors { right: parent.right; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
      text: row.checked ? "󰄬" : row.trailing
      color: row.checked ? Color.accent : Color.muted
      font.pixelSize: Style.font.icon
    }
    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.clicked()
    }
  }

  component Slider: Item {
    id: slider
    property real value: 0
    property bool dim: false
    signal moved(real value)
    height: Style.space(20)
    readonly property real fraction: Math.max(0, Math.min(1, drag.pressed ? drag.live : value))
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: Style.space(4)
      radius: height / 2
      color: Qt.rgba(1, 1, 1, 0.15)
      Rectangle {
        width: Math.max(height, parent.width * slider.fraction)
        height: parent.height
        radius: parent.radius
        color: slider.dim ? Color.muted : Color.popups.text
      }
    }
    Rectangle {
      width: Style.space(14)
      height: width
      radius: width / 2
      anchors.verticalCenter: parent.verticalCenter
      x: (slider.width - width) * slider.fraction
      color: Color.popups.text
    }
    MouseArea {
      id: drag
      property real live: 0
      anchors.fill: parent
      anchors.margins: -Style.space(6)
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      function at(x) { return Math.max(0, Math.min(1, (x - Style.space(6)) / slider.width)) }
      onPressed: function(e) { live = at(e.x); slider.moved(live) }
      onPositionChanged: function(e) { if (pressed) { live = at(e.x); slider.moved(live) } }
    }
  }
}
