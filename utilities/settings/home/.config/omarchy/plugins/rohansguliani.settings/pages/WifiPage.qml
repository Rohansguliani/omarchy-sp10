// Wi-Fi: on/off, the network you're on, networks you've used before (in
// range or not), and other networks to join. Uses quickshell's NetworkManager
// backend; saved networks out of range come from `nmcli connection show`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import "../components"

Page {
  id: page
  title: "Wi-Fi"

  headerRight: [
    Switch {
      checked: Networking.wifiEnabled
      onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }
  ]

  function findDevice(type) {
    var list = Networking.devices ? Networking.devices.values : []
    for (var i = 0; i < list.length; i++) if (list[i] && list[i].type === type) return list[i]
    return null
  }
  readonly property var wifi: findDevice(DeviceType.Wifi)
  readonly property var wired: findDevice(DeviceType.Wired)

  function isOpen(security) { return security === WifiSecurityType.Open || security === WifiSecurityType.Owe }
  function isEnterprise(security) {
    return security === WifiSecurityType.Wpa2Eap || security === WifiSecurityType.WpaEap || security === WifiSecurityType.Wpa3SuiteB192
  }
  function bars(strength) {
    var icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
    return icons[Math.max(0, Math.min(4, Math.ceil(strength * 100 / 20) - 1))]
  }

  // Plain snapshots of the scan, so delegates never hold a network object
  // that NetworkManager may drop mid-update. Actions look the object up by name.
  readonly property var scan: {
    var nets = page.wifi && page.wifi.networks ? page.wifi.networks.values : []
    var out = []
    for (var i = 0; i < nets.length; i++) {
      var n = nets[i]
      if (!n || !n.name) continue
      out.push({ name: n.name, signal: n.signalStrength || 0, security: n.security, known: n.known,
                 connected: n.connected, changing: n.stateChanging, state: n.state })
    }
    return out.sort(function(a, b) { return b.signal - a.signal })
  }
  readonly property var current: scan.filter(function(n) { return n.connected })
  readonly property var knownNearby: scan.filter(function(n) { return n.known && !n.connected })
  readonly property var others: scan.filter(function(n) { return !n.known && !n.connected })
  readonly property var knownAway: saved.filter(function(s) {
    for (var i = 0; i < page.scan.length; i++) if (page.scan[i].name === s.name) return false
    return true
  })

  function network(name) {
    var nets = page.wifi && page.wifi.networks ? page.wifi.networks.values : []
    for (var i = 0; i < nets.length; i++) if (nets[i] && nets[i].name === name) return nets[i]
    return null
  }

  property string joining: ""     // network whose password field is open
  property string error: ""
  property string errorFor: ""
  property var watched: ({})

  function watchFailures(net) {
    if (page.watched[net.name]) return
    page.watched[net.name] = true
    var name = net.name
    net.connectionFailed.connect(function(reason) {
      page.errorFor = name
      page.error = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout
        ? "Wrong password" : "Couldn't connect"
    })
  }

  function join(row) {
    var net = page.network(row.name)
    if (!net) return
    page.error = ""
    page.watchFailures(net)
    if (row.known || page.isOpen(row.security)) { page.joining = ""; net.connect() }
    else page.joining = page.joining === row.name ? "" : row.name
  }

  function joinWithPassword(name, psk) {
    var net = page.network(name)
    if (!net || psk.length === 0) return
    page.error = ""
    page.watchFailures(net)
    page.joining = ""
    net.connectWithPsk(psk)
  }

  function forget(name) {
    var net = page.network(name)
    if (net && net.known) net.forget()
    else Quickshell.execDetached(["nmcli", "connection", "delete", "id", name])
    reloadSaved.restart()
  }

  function statusOf(row) {
    if (row.changing || row.state === ConnectionState.Connecting) return "Connecting…"
    if (row.state === ConnectionState.Disconnecting) return "Disconnecting…"
    if (page.errorFor === row.name && page.error) return page.error
    return ""
  }

  // --- Saved networks (including ones out of range) --------------------------

  property var saved: []
  Process {
    id: savedQuery
    running: true
    command: ["nmcli", "-t", "-f", "NAME,TYPE,TIMESTAMP", "connection", "show"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          // Fields are ':'-separated; ':' inside a name is escaped as '\:'.
          var parts = lines[i].replace(/\\:/g, "\u0000").split(":")
          if (parts.length < 3 || parts[1] !== "802-11-wireless") continue
          out.push({ name: parts[0].replace(/\u0000/g, ":"), used: Number(parts[2]) || 0 })
        }
        page.saved = out.sort(function(a, b) { return b.used - a.used })
      }
    }
  }
  Timer { id: reloadSaved; interval: 800; onTriggered: savedQuery.running = true }
  onCurrentChanged: reloadSaved.restart()

  // IP address of the connected network.
  property string address: ""
  Process {
    id: ipQuery
    command: ["nmcli", "-g", "IP4.ADDRESS", "device", "show", page.wifi ? page.wifi.name : ""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: page.address = text.split("\n")[0].split("/")[0].trim()
    }
  }
  Timer { interval: 1500; running: page.current.length > 0 && page.wifi !== null; triggeredOnStart: true; onTriggered: ipQuery.running = true }

  // --- Layout ----------------------------------------------------------------

  Label {
    visible: !Networking.wifiEnabled
    width: parent.width
    wrapMode: Text.WordWrap
    color: Color.muted
    text: page.wifi ? "Wi-Fi is off." : "No Wi-Fi adapter found."
  }

  Group {
    visible: Networking.wifiEnabled
    title: "Connected"
    empty: "Not connected to Wi-Fi"
    showEmpty: page.current.length === 0
    Repeater {
      model: page.current
      delegate: GroupRow {
        required property var modelData
        icon: page.bars(modelData.signal)
        title: modelData.name
        subtitle: page.statusOf(modelData) || ("Connected" + (page.address ? "  ·  " + page.address : ""))
        subtitleColor: Color.accent
        PillButton { text: "Disconnect"; onClicked: { var n = page.network(modelData.name); if (n) n.disconnect() } }
        PillButton { text: "Forget"; danger: true; onClicked: page.forget(modelData.name) }
      }
    }
  }

  Group {
    visible: Networking.wifiEnabled && (page.knownNearby.length + page.knownAway.length) > 0
    title: "Previously connected"
    Repeater {
      model: page.knownNearby
      delegate: GroupRow {
        required property var modelData
        icon: page.bars(modelData.signal)
        title: modelData.name
        subtitle: page.statusOf(modelData) || "Saved"
        subtitleColor: page.errorFor === modelData.name && page.error ? Color.urgent : Color.muted
        PillButton { text: "Connect"; primary: true; busy: modelData.changing; onClicked: page.join(modelData) }
        PillButton { text: "Forget"; danger: true; onClicked: page.forget(modelData.name) }
      }
    }
    Repeater {
      model: page.knownAway
      delegate: GroupRow {
        required property var modelData
        icon: "󰤮"
        dim: true
        title: modelData.name
        subtitle: "Not in range"
        PillButton { text: "Forget"; danger: true; onClicked: page.forget(modelData.name) }
      }
    }
  }

  Group {
    visible: Networking.wifiEnabled
    title: "Other networks"
    titleRight: [
      Label {
        text: page.wifi && page.wifi.scannerEnabled ? "Searching…" : ""
        color: Color.muted
        font.pixelSize: Style.font.caption
      }
    ]
    empty: "No other networks nearby"
    showEmpty: page.others.length === 0
    Repeater {
      model: page.others
      delegate: GroupRow {
        id: otherRow
        required property var modelData
        icon: page.bars(modelData.signal)
        title: modelData.name + (page.isOpen(modelData.security) ? "" : "  󰌾")
        subtitle: page.statusOf(modelData) || (page.isEnterprise(modelData.security) ? "Enterprise network (not supported here)"
                                                  : (page.isOpen(modelData.security) ? "Open network" : "Secured"))
        subtitleColor: page.errorFor === modelData.name && page.error ? Color.urgent : Color.muted
        PillButton {
          visible: !page.isEnterprise(modelData.security)
          text: page.joining === modelData.name ? "Cancel" : "Join"
          primary: page.joining !== modelData.name
          busy: modelData.changing
          onClicked: page.join(modelData)
        }
        below: [
          Row {
            visible: page.joining === otherRow.modelData.name
            spacing: 8
            Rectangle {
              width: 320
              height: 32
              radius: Math.min(8, Style.cornerRadius + 6)
              color: Qt.rgba(1, 1, 1, 0.06)
              border.width: 1
              border.color: password.activeFocus ? Color.accent : Qt.rgba(1, 1, 1, 0.16)
              TextInput {
                id: password
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                clip: true
                focus: visible
                onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                onAccepted: page.joinWithPassword(otherRow.modelData.name, text)
                Label {
                  visible: password.text.length === 0
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Password"
                  color: Color.muted
                }
              }
            }
            PillButton { text: "Join"; primary: true; onClicked: page.joinWithPassword(otherRow.modelData.name, password.text) }
          }
        ]
      }
    }
  }

  Group {
    visible: page.wired !== null
    title: "Ethernet"
    GroupRow {
      icon: "󰈀"
      title: "Ethernet"
      subtitle: page.wired && page.wired.connected ? "Connected" : (page.wired && page.wired.hasLink ? "Cable connected, no network" : "No cable")
      subtitleColor: page.wired && page.wired.connected ? Color.accent : Color.muted
    }
  }
}
