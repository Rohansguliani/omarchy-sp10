// Devices: the mice, touchpads and keyboards that are connected. Click one for
// its settings: pointer speed, scroll speed, natural scrolling, acceleration
// or tap to click, or swapping Alt and Super on a keyboard.
//
// bin/devices does the work: `list` merges Hyprland, sysfs and udev into one
// entry per physical device (with the settings saved for it), and `set`
// validates a change, applies it live and saves it to
// ~/.config/hypr/utilities/devices.lua. Sliders apply while dragging and save
// once on release. The list refreshes every few seconds while the page is
// open, so plugging a device in or out shows up on its own.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../components"

Page {
  id: page
  title: page.selected ? page.selected.name : "Devices"
  backLabel: page.selected ? "Devices" : ""
  onBack: page.selectedId = ""

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/rohansguliani.settings/bin/devices"

  property var devices: []
  property bool loaded: false
  property string selectedId: ""
  readonly property var selected: {
    for (var i = 0; i < page.devices.length; i++) if (page.devices[i].id === page.selectedId) return page.devices[i]
    return null
  }
  // A device that was open and got unplugged: back to the list.
  onSelectedChanged: if (page.loaded && page.selectedId !== "" && !page.selected) page.selectedId = ""

  readonly property var kindIcons: ({ mouse: "󰍽", touchpad: "󰟸", keyboard: "󰌌" })
  readonly property var kindLabels: ({ mouse: "Mouse", touchpad: "Touchpad", keyboard: "Keyboard" })

  function ofKind(kinds) {
    return page.devices.filter(function(d) { return kinds.indexOf(d.kind) >= 0 })
  }

  function subtitle(d) {
    var parts = [d.connection]
    if (d.battery !== null && d.battery !== undefined) parts.push("Battery " + d.battery + "%")
    return parts.join("  ·  ")
  }

  // Apply a change: update the shown value at once, then let the helper apply
  // and save it. `save` false only applies live (while a slider drags).
  function change(setting, value, save) {
    var d = page.selected
    if (!d) return
    var next = JSON.parse(JSON.stringify(page.devices))
    for (var i = 0; i < next.length; i++) if (next[i].id === d.id) next[i].settings[setting] = value
    page.devices = next
    var request = { id: d.id, settings: {} }
    request.settings[setting] = value
    if (save) {
      Quickshell.execDetached([page.helper, "set", JSON.stringify(request)])
      refresh.restart()
    } else page.pendingLive = request
  }

  // Live updates while dragging, at most every 60 ms.
  property var pendingLive: null
  Timer {
    interval: 60
    running: page.pendingLive !== null
    onTriggered: {
      Quickshell.execDetached([page.helper, "set", JSON.stringify(page.pendingLive)])
      page.pendingLive = null
    }
  }

  Process {
    id: lister
    running: true
    command: [page.helper, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { page.devices = JSON.parse(text) } catch (error) {}
        page.loaded = true
      }
    }
  }
  Timer {
    id: refresh
    interval: 3000
    repeat: true
    running: page.visible && !lister.running && page.pendingLive === null
    onTriggered: lister.running = true
  }

  // --- List -----------------------------------------------------------------

  Repeater {
    model: page.selected ? [] : [
      { title: "Mice & Touchpads", kinds: ["mouse", "touchpad"], empty: "No mouse or touchpad connected" },
      { title: "Keyboards", kinds: ["keyboard"], empty: "No keyboard connected" }
    ]
    delegate: Group {
      id: section
      required property var modelData
      readonly property var items: page.ofKind(modelData.kinds)
      title: modelData.title
      empty: page.loaded ? modelData.empty : "Looking for devices…"
      showEmpty: items.length === 0

      Repeater {
        model: section.items
        delegate: GroupRow {
          required property var modelData
          icon: page.kindIcons[modelData.kind]
          title: modelData.name
          subtitle: page.subtitle(modelData)
          clickable: true
          onClicked: page.selectedId = modelData.id
          Label { text: "›"; color: Color.muted; font.pixelSize: Style.font.subtitle }
        }
      }
    }
  }

  // --- Detail ---------------------------------------------------------------

  // A labelled slider row; `low`..`high` maps onto the shared 0..1 Slider.
  component SliderRow: GroupRow {
    id: sliderRow
    property string setting: ""
    property real low: 0
    property real high: 1
    property string lowLabel: ""
    property string highLabel: ""
    property real current: page.selected ? page.selected.settings[setting] : low
    function at(v) { return Math.round((low + v * (high - low)) * 20) / 20 }

    Label { text: sliderRow.lowLabel; color: Color.muted; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
    Slider {
      width: 240
      anchors.verticalCenter: parent.verticalCenter
      value: (sliderRow.current - sliderRow.low) / (sliderRow.high - sliderRow.low)
      onMoved: function(v) { page.change(sliderRow.setting, sliderRow.at(v), false) }
      onReleased: function(v) { page.change(sliderRow.setting, sliderRow.at(v), true) }
    }
    Label { text: sliderRow.highLabel; color: Color.muted; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
  }

  component SwitchRow: GroupRow {
    id: switchRow
    property string setting: ""
    readonly property bool isOn: page.selected ? page.selected.settings[setting] === true : false
    Switch {
      anchors.verticalCenter: parent.verticalCenter
      checked: switchRow.isOn
      onToggled: page.change(switchRow.setting, !switchRow.isOn, true)
    }
  }

  Group {
    visible: page.selected !== null
    title: page.selected ? page.kindLabels[page.selected.kind] : ""

    GroupRow {
      icon: page.selected ? page.kindIcons[page.selected.kind] : ""
      title: page.selected ? page.selected.name : ""
      subtitle: page.selected ? page.subtitle(page.selected) : ""
    }
  }

  Group {
    visible: page.selected !== null && page.selected.kind !== "keyboard"
    title: "Pointer"

    SliderRow {
      title: "Tracking speed"
      setting: "speed"
      low: -1
      high: 1
      lowLabel: "Slow"
      highLabel: "Fast"
    }
    SwitchRow {
      visible: page.selected !== null && page.selected.kind === "mouse"
      title: "Pointer acceleration"
      subtitle: "Moving faster moves the pointer further"
      setting: "acceleration"
    }
    SwitchRow {
      visible: page.selected !== null && page.selected.kind === "touchpad"
      title: "Tap to click"
      setting: "tap_to_click"
    }
  }

  Group {
    visible: page.selected !== null && page.selected.kind !== "keyboard"
    title: "Scrolling"

    SliderRow {
      title: "Scroll speed"
      setting: "scroll"
      low: page.selected && page.selected.kind === "touchpad" ? 0.1 : 0.2
      high: page.selected && page.selected.kind === "touchpad" ? 2 : 4
      lowLabel: "Slow"
      highLabel: "Fast"
    }
    SwitchRow {
      title: "Natural scrolling"
      subtitle: "Content moves with your fingers"
      setting: "natural_scroll"
    }
  }

  Group {
    visible: page.selected !== null && page.selected.kind === "keyboard"
    title: "Keys"
    note: "For keyboards in Mac mode, where the key next to the space bar is ⌘ (Super). On, it acts as Alt, so Alt shortcuts land where your thumb is."

    SwitchRow {
      title: "Swap Alt and Super"
      setting: "swap_alt_super"
    }
  }

  Group {
    visible: page.selected !== null && page.selected.extras.length > 0
    title: "Buttons"

    Repeater {
      model: page.selected ? page.selected.extras : []
      delegate: GroupRow {
        required property var modelData
        title: modelData.title
        Label { text: modelData.value; color: Color.muted; anchors.verticalCenter: parent.verticalCenter }
      }
    }
  }
}
