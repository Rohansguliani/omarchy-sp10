// About: what this computer is. Read once each time the page opens.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../components"

Page {
  id: page
  title: "About"

  property var info: ({})

  Process {
    running: true
    command: ["bash", "-c", [
      "printf 'model\\t%s %s\\n' \"$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)\" \"$(cat /sys/class/dmi/id/product_name 2>/dev/null)\"",
      "printf 'name\\t%s\\n' \"$(cat /etc/hostname 2>/dev/null)\"",
      "printf 'omarchy\\t%s\\n' \"$(omarchy version 2>/dev/null)\"",
      "printf 'kernel\\t%s\\n' \"$(uname -r)\"",
      "printf 'cpu\\t%s\\n' \"$(lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -1)\"",
      "printf 'gpu\\t%s\\n' \"$(lspci | grep -iE 'vga|3d|display' | sed 's/^.*controller: //; s/ (rev .*)//' | head -2 | paste -sd ', ')\"",
      "printf 'memory\\t%s\\n' \"$(awk '/^MemTotal:/{printf \"%d GB\", $2/1048576 + 0.5}' /proc/meminfo)\"",
      "printf 'disk\\t%s\\n' \"$(df -h --output=avail,size / | awk 'NR==2{print $1\" free of \"$2}')\"",
      "printf 'uptime\\t%s\\n' \"$(uptime -p | sed 's/^up //')\""
    ].join("; ")]
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

  Column {
    width: parent.width
    spacing: 4
    Label {
      text: page.info.model || ""
      font.pixelSize: Style.font.title
      font.weight: Font.DemiBold
    }
    Label {
      text: page.info.omarchy ? "Omarchy " + page.info.omarchy : ""
      color: Color.muted
    }
  }

  Group {
    title: "Hardware"
    Repeater {
      model: [
        { key: "cpu", label: "Processor" },
        { key: "gpu", label: "Graphics" },
        { key: "memory", label: "Memory" },
        { key: "disk", label: "Storage" }
      ]
      delegate: GroupRow {
        required property var modelData
        title: modelData.label
        Label { text: page.info[modelData.key] || "—"; color: Color.muted; width: 380; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
      }
    }
  }

  Group {
    title: "Software"
    Repeater {
      model: [
        { key: "name", label: "Computer name" },
        { key: "omarchy", label: "Omarchy" },
        { key: "kernel", label: "Kernel" },
        { key: "uptime", label: "Up for" }
      ]
      delegate: GroupRow {
        required property var modelData
        title: modelData.label
        Label { text: page.info[modelData.key] || "—"; color: Color.muted; width: 380; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
      }
    }
  }
}
