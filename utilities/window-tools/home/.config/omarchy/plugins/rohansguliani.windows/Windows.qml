// Shell half of the window tools: hosts the Alt+Tab switcher
// (switcher/Switcher.qml) and Mission Control (mission-control/MissionControl.qml),
// and the helpers both use. Keys, gestures and window changes live in the
// .lua file next to each; panels reach them through
// `hyprctl eval 'windowtools.…'`.
//
//   omarchy-shell windows switcherShow '<json>' | switcherSelect N | switcherHide
//   omarchy-shell windows overviewOpen | overviewClose | overviewToggle | state

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "switcher"
import "mission-control"
import "edge-snap"

Item {
  id: root

  // Injected by Omarchy's panel loader.
  property var shell: null
  property var manifest: null
  // Never "open" as far as the shell is concerned, so `shell summon` always
  // delivers to open() below.
  readonly property bool opened: false

  // The fast path from the .lua files: `omarchy-shell shell summon
  // rohansguliani.windows '{"cmd":...,"data":...}'` goes over the shell's own
  // socket and lands here.
  function open(payloadJson) {
    var request
    try { request = JSON.parse(payloadJson || "{}") } catch (error) { return }
    var data = request.data
    switch (request.cmd) {
    case "switcherShow": switcher.show(data); break
    case "switcherSelect": switcher.select(Number(data)); break
    case "switcherHide": switcher.hide(); break
    case "overviewOpen": overview.open(data); break
    case "overviewUpdate": overview.update(data); break
    case "overviewClose": overview.closeToHovered(); break
    case "overviewToggle": overview.opened ? overview.closeToHovered() : overview.open(data); break
    case "edgeSnapShow": edgeSnap.show(data); break
    case "edgeSnapHide": edgeSnap.hide(); break
    }
  }

  function close() {
    switcher.hide()
    overview.close()
  }

  function normalAddress(value) {
    var v = String(value || "").toLowerCase()
    return v.indexOf("0x") === 0 ? v : "0x" + v
  }

  function addressOf(toplevel) {
    if (!toplevel) return ""
    var ipc = toplevel.lastIpcObject || {}
    return normalAddress(toplevel.address || ipc.address)
  }

  function toplevelFor(address) {
    var wanted = normalAddress(address)
    var list = Hyprland.toplevels.values
    for (var i = 0; i < list.length; i++)
      if (addressOf(list[i]) === wanted) return list[i]
    return null
  }

  function classOf(toplevel) {
    if (!toplevel) return ""
    var ipc = toplevel.lastIpcObject || {}
    return String((toplevel.wayland && toplevel.wayland.appId) || ipc.class || ipc.initialClass || "")
  }

  function appIcon(appClass) {
    var raw = String(appClass || "").trim()
    var entry = raw ? DesktopEntries.heuristicLookup(raw) : null
    var icon = entry ? String(entry.icon || "") : ""
    if (icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0) return icon
    if (icon.charAt(0) === "/") return "file://" + icon
    // Hicolor-only icons (Helium's) aren't always found by the themed lookup.
    var themed = Quickshell.iconPath(icon || raw, true)
    if (themed) return themed
    var name = icon || raw
    if (/^[A-Za-z0-9._+-]+$/.test(name)) return "file:///usr/share/icons/hicolor/256x256/apps/" + name + ".png"
    return Quickshell.iconPath("application-x-executable", true)
  }

  // Run a windowtools.* call in Hyprland. Only addresses and integers are
  // ever interpolated, and both are validated by the callers.
  function lua(expression) {
    Quickshell.execDetached(["hyprctl", "eval", expression])
  }

  function focusWindow(address) {
    var a = normalAddress(address)
    if (/^0x[0-9a-f]+$/.test(a)) lua('windowtools.focus("' + a + '")')
  }

  // The Quickshell screen for a Hyprland monitor name; the first screen if
  // there is no such monitor.
  function screenFor(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) if (screens[i].name === name) return screens[i]
    return screens.length > 0 ? screens[0] : null
  }

  Switcher { id: switcher; host: root }
  MissionControl { id: overview; host: root }
  EdgeSnapPreview { id: edgeSnap; host: root }

  IpcHandler {
    target: "windows"

    function switcherShow(payloadJson: string): string { switcher.show(JSON.parse(payloadJson)); return "ok" }
    function switcherSelect(index: int): string { switcher.select(index); return "ok" }
    function switcherHide(): string { switcher.hide(); return "ok" }
    function overviewOpen(): string { root.lua('windowtools.overview("overviewOpen")'); return "ok" }
    function overviewClose(): string { overview.closeToHovered(); return "ok" }
    function overviewToggle(): string { root.lua('windowtools.overview("overviewToggle")'); return "ok" }
    function state(): string { return JSON.stringify({ switcher: switcher.requested, overview: overview.opened }) }
  }
}
