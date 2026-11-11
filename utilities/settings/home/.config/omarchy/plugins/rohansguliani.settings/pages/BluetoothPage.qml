// Bluetooth: on/off, connected devices, devices paired before, and devices
// nearby to pair. Settings.qml scans only while this page is on screen.
// Actions go through Omarchy's own helpers (omarchy-bluetooth-device
// pair|connect|disconnect|forget, omarchy-bluetooth-power).
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Commons
import "../components"

Page {
  id: page
  title: "Bluetooth"

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool powered: adapter !== null && adapter.enabled
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []

  headerRight: [
    Switch {
      visible: page.adapter !== null
      checked: page.powered
      onToggled: Quickshell.execDetached(["omarchy-bluetooth-power", page.powered ? "off" : "on"])
    }
  ]

  // `name` is the alias (yours, after a rename); `deviceName` what the device
  // calls itself.
  function label(d) { return String(d.name || d.deviceName || "").trim() }
  // Nameless beacons (an address or a UUID for a name) are noise.
  function hasName(d) {
    var t = page.label(d)
    return t !== "" && !/^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(t)
      && !/^[0-9a-f]{8}-[0-9a-f]{4}-/i.test(t) && !/^[0-9a-f]{32}$/i.test(t)
  }
  // Only paired devices are yours. Not "trusted": omarchy-bluetooth-device
  // trusts a device even when pairing fails, which left strangers' gadgets
  // listed as previously connected.
  function known(d) { return d.paired || d.bonded }
  function byName(a, b) { return page.label(a).localeCompare(page.label(b)) }

  readonly property var connected: devices.filter(function(d) { return d && d.connected }).sort(byName)
  readonly property var mine: devices.filter(function(d) { return d && !d.connected && page.known(d) }).sort(byName)
  readonly property var nearby: devices.filter(function(d) { return d && !d.connected && !page.known(d) && page.hasName(d) }).sort(byName)

  function icon(d) {
    var i = String(d.icon || "")
    if (/headset|headphone|audio-card/.test(i)) return "󰋋"
    if (/speaker/.test(i)) return "󰓃"
    if (/keyboard/.test(i)) return "󰌌"
    if (/mouse/.test(i)) return "󰍽"
    if (/phone/.test(i)) return "󰏲"
    if (/gaming|joystick/.test(i)) return "󰊴"
    if (/computer/.test(i)) return "󰌢"
    return "󰂯"
  }

  // address -> "connecting" | "pairing" | "disconnecting" | "forgetting"
  property var pending: ({})
  function setPending(address, action) {
    var next = ({})
    for (var k in page.pending) next[k] = page.pending[k]
    if (action) next[address] = action
    else delete next[address]
    page.pending = next
  }
  function act(d, action, state) {
    if (!d || !/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(String(d.address))) return
    page.setPending(d.address, state)
    Quickshell.execDetached(["omarchy-bluetooth-device", action, d.address])
    clearPending.restart()
  }
  // The helper gives up after 20 s per step. A pair that never completed is
  // untrusted again, so the device doesn't keep reconnecting rights.
  Timer {
    id: clearPending
    interval: 45000
    onTriggered: {
      for (var address in page.pending) {
        if (page.pending[address] !== "pairing") continue
        var d = page.find(address)
        if (d && !page.known(d)) Quickshell.execDetached(["bluetoothctl", "untrust", address])
      }
      page.pending = ({})
    }
  }
  function find(address) {
    for (var i = 0; i < page.devices.length; i++) if (page.devices[i] && page.devices[i].address === address) return page.devices[i]
    return null
  }
  // Sets the BlueZ alias, so the new name shows everywhere.
  function rename(d, text) { if (d) d.name = text }
  Timer { interval: 500; repeat: true; running: Object.keys(page.pending).length > 0; onTriggered: page.settle() }
  function settle() {
    var next = ({}), changed = false
    for (var address in page.pending) {
      var action = page.pending[address], d = null
      for (var i = 0; i < page.devices.length; i++) if (page.devices[i] && page.devices[i].address === address) d = page.devices[i]
      var done = (action === "connecting" && d && d.connected)
        || (action === "pairing" && d && page.known(d) && d.connected)
        || (action === "disconnecting" && d && !d.connected)
        || (action === "forgetting" && (!d || !page.known(d)))
      if (done) changed = true
      else next[address] = action
    }
    if (changed) page.pending = next
  }

  function status(d) {
    var busy = page.pending[d.address] || ""
    if (busy === "connecting") return "Connecting…"
    if (busy === "pairing") return "Pairing…"
    if (busy === "disconnecting") return "Disconnecting…"
    if (busy === "forgetting") return "Forgetting…"
    var parts = [d.connected ? "Connected" : (page.known(d) ? "Not connected" : "Ready to pair")]
    if (d.batteryAvailable) parts.push("battery " + Math.round(d.battery * 100) + "%")
    return parts.join("  ·  ")
  }

  Label {
    visible: !page.powered
    width: parent.width
    color: Color.muted
    text: page.adapter ? "Bluetooth is off." : "No Bluetooth adapter found."
  }

  Group {
    visible: page.powered
    title: "Connected"
    empty: "No devices connected"
    showEmpty: page.connected.length === 0
    Repeater {
      model: page.connected
      delegate: GroupRow {
        required property var modelData
        icon: page.icon(modelData)
        title: page.label(modelData) || modelData.address
        subtitle: page.status(modelData)
        subtitleColor: Color.accent
        editable: page.known(modelData)
        onRenamed: function(text) { page.rename(modelData, text) }
        PillButton { text: "Disconnect"; busy: (page.pending[modelData.address] || "") !== ""; onClicked: page.act(modelData, "disconnect", "disconnecting") }
        PillButton { text: "Forget"; danger: true; onClicked: page.act(modelData, "forget", "forgetting") }
      }
    }
  }

  Group {
    visible: page.powered
    title: "Previously connected"
    empty: "No other paired devices"
    showEmpty: page.mine.length === 0
    Repeater {
      model: page.mine
      delegate: GroupRow {
        required property var modelData
        icon: page.icon(modelData)
        title: page.label(modelData) || modelData.address
        subtitle: page.status(modelData)
        editable: true
        onRenamed: function(text) { page.rename(modelData, text) }
        PillButton { text: "Connect"; primary: true; busy: (page.pending[modelData.address] || "") !== ""; onClicked: page.act(modelData, "connect", "connecting") }
        PillButton { text: "Forget"; danger: true; onClicked: page.act(modelData, "forget", "forgetting") }
      }
    }
  }

  Group {
    visible: page.powered
    title: "Nearby"
    titleRight: [
      Label {
        text: page.adapter && page.adapter.discovering ? "Searching…" : ""
        color: Color.muted
        font.pixelSize: Style.font.caption
      }
    ]
    note: "Put a device in pairing mode to see it here."
    empty: "No devices in pairing mode nearby"
    showEmpty: page.nearby.length === 0
    Repeater {
      model: page.nearby
      delegate: GroupRow {
        required property var modelData
        icon: page.icon(modelData)
        title: page.label(modelData)
        subtitle: page.status(modelData)
        PillButton { text: "Pair"; primary: true; busy: (page.pending[modelData.address] || "") !== ""; onClicked: page.act(modelData, "pair", "pairing") }
      }
    }
  }
}
