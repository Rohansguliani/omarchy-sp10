// Battery: charge, state, time left and health from Omarchy's own battery
// helper, and the power mode (remembered separately for charger and battery
// by omarchy-powerprofiles-set).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import "../components"

Page {
  id: page
  title: "Battery"

  property var info: ({})
  property string profile: ""

  Process {
    id: status
    command: ["omarchy-battery-status", "--shell"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = ({})
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var tab = lines[i].indexOf("\t")
          if (tab > 0) next[lines[i].slice(0, tab)] = lines[i].slice(tab + 1).trim()
        }
        page.info = next
      }
    }
  }
  Process {
    id: profiles
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          if (parts[1] === "1") page.profile = parts[0]
        }
      }
    }
  }
  Timer {
    interval: 5000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: { status.running = true; profiles.running = true }
  }
  Connections {
    target: UPower
    function onOnBatteryChanged() { status.running = true; profiles.running = true }
  }

  readonly property string state: String(info.state || "")
  function stateText() {
    switch (page.state) {
      case "charging": return "Charging"
      case "discharging": return "On battery"
      case "fully-charged": return "Fully charged"
      case "pending-charge": return "Plugged in, not charging"
      case "pending-discharge": return "Plugged in"
      default: return UPower.onBattery ? "On battery" : "Plugged in"
    }
  }
  readonly property int level: parseInt(info.percentage) || 0
  function levelIcon() {
    var icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    if (page.state === "charging") return "󰂄"
    return icons[Math.max(0, Math.min(10, Math.round(page.level / 10)))]
  }

  function setProfile(name) {
    page.profile = name
    Quickshell.execDetached(["omarchy-powerprofiles-set", "autodetect", name])
  }

  Group {
    title: "Status"
    GroupRow {
      icon: page.levelIcon()
      title: page.info.percentage || "—"
      subtitle: page.stateText()
      subtitleColor: page.state === "charging" ? Color.accent : Color.muted
      Rectangle {
        width: 180
        height: 10
        radius: 5
        color: Qt.rgba(1, 1, 1, 0.12)
        Rectangle {
          width: parent.width * page.level / 100
          height: parent.height
          radius: parent.radius
          color: page.level <= 15 && page.state !== "charging" ? Color.urgent : Color.accent
        }
      }
    }
    GroupRow {
      visible: (page.info.time || "") !== ""
      title: page.state === "charging" ? "Time until full" : "Time left"
      Label { text: page.info.time || ""; color: Color.muted }
    }
    GroupRow {
      visible: (page.info.rate || "") !== "" && page.info.rate !== "0W"
      title: page.state === "charging" ? "Charging at" : "Using"
      Label { text: page.info.rate || ""; color: Color.muted }
    }
  }

  Group {
    title: "Power mode"
    note: "Remembered separately for when you're plugged in and on battery."
    Repeater {
      model: [
        { id: "power-saver", label: "Low Power", detail: "Longest battery life", icon: "󰌪" },
        { id: "balanced", label: "Balanced", detail: "Normal performance and battery life", icon: "󰗑" },
        { id: "performance", label: "High Performance", detail: "Fastest; uses more power and runs warmer", icon: "󰓅" }
      ]
      delegate: GroupRow {
        id: modeRow
        required property var modelData
        icon: modelData.icon
        title: modelData.label
        subtitle: modelData.detail
        clickable: page.profile !== modelData.id
        onClicked: page.setProfile(modelData.id)
        Label { visible: page.profile === modeRow.modelData.id; text: "󰄬"; color: Color.accent; font.pixelSize: Style.font.icon }
      }
    }
  }

  Group {
    title: "Health"
    note: "Locked and idle on battery for 10 minutes, the computer goes to sleep. Plugged in, it stays awake."
    GroupRow {
      title: "Capacity"
      Label { text: page.info.size || "—"; color: Color.muted }
    }
    GroupRow {
      title: "Charge cycles"
      Label { text: page.info.cycles || "—"; color: Color.muted }
    }
  }
}
