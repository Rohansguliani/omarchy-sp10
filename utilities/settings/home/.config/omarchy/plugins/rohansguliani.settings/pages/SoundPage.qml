// Sound: output and input device, their volume, and a volume per app.
// Delegates hold node ids, not PwNode objects: PipeWire deletes nodes outright
// and a delegate still holding one can crash the shell (see Omarchy's audio
// panel). Nodes are looked up by id when drawn or changed.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import "../components"

Page {
  id: page
  title: "Sound"

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

  function isSource(n) {
    if (n.audio) return true
    var t = String(n.type || "")
    return t.indexOf("Source") !== -1
  }
  readonly property var outputs: nodes.filter(function(n) { return n && n.isSink && !n.isStream })
  readonly property var inputs: nodes.filter(function(n) { return n && !n.isSink && !n.isStream && page.isSource(n) && n.name !== "quickshell" })
  readonly property var apps: nodes.filter(function(n) {
    return n && n.isStream && n.isSink && String(n.name || "").indexOf("omarchy_speaker_tuning") !== 0
  })

  PwObjectTracker { objects: page.outputs.concat(page.inputs).concat(page.apps) }

  function ids(list) { return list.map(function(n) { return n.id }) }
  function node(id) {
    for (var i = 0; i < page.nodes.length; i++) if (page.nodes[i] && page.nodes[i].id === id) return page.nodes[i]
    return null
  }
  function deviceLabel(n) {
    if (!n) return ""
    // The description is the full name ("HP USB-C Universal Docking Station
    // Analog Stereo"); the nickname is a cut-off ALSA name.
    var t = String(n.description || n.nickname || n.name || "Unknown")
    t = t.replace(/ (Analog|Digital) Stereo.*$| Pro( \d+)?$/, "")
    // "HP USB-C Universal Docking Station" -> "HP Dock".
    t = t.replace(/ (USB-C |Thunderbolt )?(Universal )?Dock(ing Station)?( G\d)?$/i, " Dock")
    if (/^Built-in Audio$/.test(t) || /alsa_output\.pci/.test(n.name)) return "Speakers"
    return t
  }
  function appLabel(n) {
    if (!n) return ""
    var p = n.ready && n.properties ? n.properties : {}
    return String(p["application.name"] || n.description || p["media.name"] || n.name || "App")
  }
  function outputIcon(n) {
    var t = (String(n.name) + " " + page.deviceLabel(n)).toLowerCase()
    if (/bluez|headphone|headset|airpods/.test(t)) return "󰋋"
    if (/hdmi|displayport|dock|monitor/.test(t)) return "󰍹"
    return "󰓃"
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource

  Group {
    title: "Output"
    GroupRow {
      icon: page.sink && page.sink.audio && page.sink.audio.muted ? "󰖁" : "󰕾"
      title: "Volume"
      clickable: false
      Slider {
        width: 260
        value: page.sink && page.sink.audio ? page.sink.audio.volume : 0
        muted: page.sink && page.sink.audio ? page.sink.audio.muted : false
        onMoved: function(v) { if (page.sink && page.sink.audio) { page.sink.audio.muted = false; page.sink.audio.volume = v } }
      }
      Label {
        width: 40
        horizontalAlignment: Text.AlignRight
        color: Color.muted
        text: page.sink && page.sink.audio ? Math.round(page.sink.audio.volume * 100) + "%" : ""
      }
      PillButton {
        text: page.sink && page.sink.audio && page.sink.audio.muted ? "Unmute" : "Mute"
        onClicked: if (page.sink && page.sink.audio) page.sink.audio.muted = !page.sink.audio.muted
      }
    }
    Repeater {
      model: page.ids(page.outputs)
      delegate: GroupRow {
        id: outRow
        required property var modelData
        readonly property var n: page.node(modelData)
        readonly property bool active: page.sink !== null && n !== null && page.sink.id === n.id
        icon: n ? page.outputIcon(n) : ""
        title: page.deviceLabel(n)
        subtitle: active ? "Playing here" : ""
        subtitleColor: Color.accent
        clickable: !active
        onClicked: if (n) Pipewire.preferredDefaultAudioSink = n
        Label { visible: outRow.active; text: "󰄬"; color: Color.accent; font.pixelSize: Style.font.icon }
      }
    }
  }

  Group {
    title: "Input"
    empty: "No microphones"
    showEmpty: page.inputs.length === 0
    GroupRow {
      visible: page.inputs.length > 0
      icon: page.source && page.source.audio && page.source.audio.muted ? "󰍭" : "󰍬"
      title: "Input volume"
      Slider {
        width: 260
        value: page.source && page.source.audio ? page.source.audio.volume : 0
        muted: page.source && page.source.audio ? page.source.audio.muted : false
        onMoved: function(v) { if (page.source && page.source.audio) { page.source.audio.muted = false; page.source.audio.volume = v } }
      }
      Label {
        width: 40
        horizontalAlignment: Text.AlignRight
        color: Color.muted
        text: page.source && page.source.audio ? Math.round(page.source.audio.volume * 100) + "%" : ""
      }
      PillButton {
        text: page.source && page.source.audio && page.source.audio.muted ? "Unmute" : "Mute"
        onClicked: if (page.source && page.source.audio) page.source.audio.muted = !page.source.audio.muted
      }
    }
    Repeater {
      model: page.ids(page.inputs)
      delegate: GroupRow {
        id: inRow
        required property var modelData
        readonly property var n: page.node(modelData)
        readonly property bool active: page.source !== null && n !== null && page.source.id === n.id
        icon: "󰍬"
        title: page.deviceLabel(n)
        subtitle: active ? "In use" : ""
        subtitleColor: Color.accent
        clickable: !active
        onClicked: if (n) Pipewire.preferredDefaultAudioSource = n
        Label { visible: inRow.active; text: "󰄬"; color: Color.accent; font.pixelSize: Style.font.icon }
      }
    }
  }

  Group {
    title: "Apps"
    empty: "No apps are playing sound"
    showEmpty: page.apps.length === 0
    note: "Bluetooth headphones and speakers take over the output when they connect."
    Repeater {
      model: page.ids(page.apps)
      delegate: GroupRow {
        required property var modelData
        readonly property var n: page.node(modelData)
        icon: n && n.audio && n.audio.muted ? "󰖁" : "󰝚"
        title: page.appLabel(n)
        Slider {
          width: 220
          value: n && n.audio ? n.audio.volume : 0
          muted: n && n.audio ? n.audio.muted : false
          onMoved: function(v) { var x = page.node(modelData); if (x && x.audio) { x.audio.muted = false; x.audio.volume = v } }
        }
        Label {
          width: 40
          horizontalAlignment: Text.AlignRight
          color: Color.muted
          text: n && n.audio ? Math.round(n.audio.volume * 100) + "%" : ""
        }
        PillButton {
          text: n && n.audio && n.audio.muted ? "Unmute" : "Mute"
          onClicked: { var x = page.node(modelData); if (x && x.audio) x.audio.muted = !x.audio.muted }
        }
      }
    }
  }
}
