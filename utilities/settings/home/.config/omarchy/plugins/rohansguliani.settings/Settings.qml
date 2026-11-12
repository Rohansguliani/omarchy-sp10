// Settings: one window for Wi-Fi, Bluetooth, Sound, Displays, Devices,
// Battery and About. A real window (shows in Alt+Tab and the taskbar), drawn by the shell
// so it opens instantly.
//
//   omarchy-shell shell summon rohansguliani.settings '{"page":"wifi"}'
//   (bin/settings-open [page] does the same)
//
// Radios only scan while their page is on screen: Wi-Fi scanning and
// Bluetooth discovery start when you open that page and stop when you leave
// it or close the window.

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.Commons
import "components"

Item {
  id: root

  // Injected by Omarchy's panel loader.
  property var shell: null
  property var manifest: null
  // Never "open" as far as the shell is concerned, so every summon reaches
  // open() (which also switches page).
  readonly property bool opened: false

  readonly property var pages: [
    { id: "wifi", label: "Wi-Fi", icon: "󰖩", file: "WifiPage.qml" },
    { id: "bluetooth", label: "Bluetooth", icon: "󰂯", file: "BluetoothPage.qml" },
    { id: "sound", label: "Sound", icon: "󰕾", file: "SoundPage.qml" },
    { id: "displays", label: "Displays", icon: "󰍹", file: "DisplaysPage.qml" },
    { id: "devices", label: "Devices", icon: "󰍽", file: "DevicesPage.qml" },
    { id: "battery", label: "Battery", icon: "󰁹", file: "BatteryPage.qml" },
    { id: "about", label: "About", icon: "󰋼", file: "AboutPage.qml" }
  ]
  property string page: "wifi"

  function pageInfo(id) {
    for (var i = 0; i < pages.length; i++) if (pages[i].id === id) return pages[i]
    return pages[0]
  }

  function open(payloadJson) {
    var request = ({})
    try { request = JSON.parse(payloadJson || "{}") } catch (error) {}
    if (request.cmd === "close") { window.visible = false; return }
    if (request.page) root.page = root.pageInfo(String(request.page)).id
    // Already open: map it again, so it comes up on the current workspace
    // with focus instead of staying wherever it was.
    if (window.visible) window.visible = false
    window.visible = true
  }

  function close() { window.visible = false }

  // --- Scanning -------------------------------------------------------------

  readonly property var wifiDevice: {
    var list = Networking.devices ? Networking.devices.values : []
    for (var i = 0; i < list.length; i++) if (list[i] && list[i].type === DeviceType.Wifi) return list[i]
    return null
  }
  readonly property bool scanWifi: window.visible && root.page === "wifi" && Networking.wifiEnabled
  onScanWifiChanged: if (root.wifiDevice) root.wifiDevice.scannerEnabled = root.scanWifi
  onWifiDeviceChanged: if (root.wifiDevice) root.wifiDevice.scannerEnabled = root.scanWifi

  // BlueZ refuses discovery while the adapter powers up and may end it on its
  // own, so it is nudged back on while the page is open. The stop is a timer
  // on the confirmed state, not a one-off write: quickshell drops a write equal
  // to the last state BlueZ reported, so a stop sent before a start is
  // confirmed would be lost and leave the radio scanning, which starves
  // Bluetooth audio.
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool scanBluetooth: window.visible && root.page === "bluetooth"
  property bool owesDiscoveryStop: false
  Timer {
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: root.scanBluetooth && root.btAdapter !== null && root.btAdapter.enabled && !root.btAdapter.discovering
    onTriggered: { root.owesDiscoveryStop = true; root.btAdapter.discovering = true }
  }
  Timer {
    interval: 1000
    repeat: true
    property int attempts: 0
    running: !root.scanBluetooth && root.owesDiscoveryStop && root.btAdapter !== null && root.btAdapter.discovering === true
    onRunningChanged: if (running) attempts = 0
    onTriggered: {
      attempts += 1
      if (attempts > 3) { root.owesDiscoveryStop = false; return }
      root.btAdapter.discovering = false
    }
  }
  Connections {
    target: root.btAdapter
    function onDiscoveringChanged() { if (!root.btAdapter.discovering) root.owesDiscoveryStop = false }
  }

  // --- Window ---------------------------------------------------------------

  FloatingWindow {
    id: window
    visible: false
    title: "Settings"
    color: Color.background
    implicitWidth: 980
    implicitHeight: 700
    minimumSize: Qt.size(760, 520)
    // Closed by the compositor (Super+W, a window close): Quickshell drops the
    // backing window but leaves `visible` true, so the next open() would toggle
    // a window that no longer exists and nothing would appear.
    onClosed: window.visible = false

    Item {
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) { window.visible = false; event.accepted = true }
      }
    }

    Rectangle {
      id: sidebar
      width: 220
      height: parent.height
      color: Qt.rgba(1, 1, 1, 0.03)

      Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.07) }

      Column {
        x: 12
        y: 18
        width: parent.width - 24
        spacing: 2

        Label {
          x: 10
          height: 40
          verticalAlignment: Text.AlignVCenter
          text: "Settings"
          font.pixelSize: Style.font.subtitle
          font.weight: Font.DemiBold
        }

        Repeater {
          model: root.pages
          delegate: Rectangle {
            id: item
            required property var modelData
            readonly property bool current: root.page === modelData.id
            width: parent.width
            height: 36
            radius: Math.min(8, Style.cornerRadius + 6)
            color: current ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
                           : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            Label {
              id: itemIcon
              anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
              width: 22
              horizontalAlignment: Text.AlignHCenter
              text: item.modelData.icon
              font.pixelSize: Style.font.icon
              color: item.current ? Color.accent : Color.foreground
            }
            Label {
              anchors { left: itemIcon.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
              text: item.modelData.label
              font.weight: item.current ? Font.DemiBold : Font.Normal
            }
            MouseArea {
              id: itemMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.page = item.modelData.id
            }
          }
        }
      }
    }

    Loader {
      anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }
      active: window.visible
      source: "pages/" + root.pageInfo(root.page).file
    }
  }
}
