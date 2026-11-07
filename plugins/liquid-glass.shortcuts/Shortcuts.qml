import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Liquid Glass — raccourcis d'apps dans la barre des menus. La liste vient de
// config.json (shortcuts.apps, Réglages → Raccourcis) : « claude-code » pour
// Claude Code (omarchy-agent), sinon l'id .desktop d'une app. Clic : lance
// l'app, ou passe sur sa fenêtre si elle est déjà ouverte (comme le Dock).
Panel {
  id: root
  moduleName: "liquid-glass.shortcuts"
  ipcTarget: "liquid-glass.shortcuts"
  readonly property color tint: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property var appLibrary: root.bar && root.bar.shell ? root.bar.shell.appLibrary : null

  property var cfg: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.config/liquid-glass/config.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }
  readonly property var ids: {
    var a = root.cfg.shortcuts ? root.cfg.shortcuts.apps : undefined
    return Array.isArray(a) ? a : ["claude-code"]
  }

  function entryFor(id) {
    var all = DesktopEntries.applications.values
    var want = String(id).toLowerCase().replace(/\.desktop$/, "")
    for (var i = 0; i < all.length; i++)
      if (String(all[i].id).toLowerCase().replace(/\.desktop$/, "") === want) return all[i]
    return null
  }
  readonly property var items: {
    var _ = DesktopEntries.applications.values.length
    var out = []
    for (var i = 0; i < ids.length; i++) {
      var id = ids[i]
      if (id === "claude-code") {
        out.push({ id: id, name: "Claude Code", icon: "file:///usr/share/omarchy/shell/plugins/agents/assets/claude.svg", entry: null, wm: "" })
        continue
      }
      var e = entryFor(id)
      if (!e) continue
      var src = root.appLibrary ? root.appLibrary.iconSource(e.icon) : Quickshell.iconPath(e.icon, true)
      out.push({ id: id, name: e.name, icon: src, entry: e, wm: String(e.startupClass || e.id || "").toLowerCase() })
    }
    return out
  }

  function windowFor(it) {
    if (!it.entry) return null
    var keys = [it.wm, String(it.id).toLowerCase().replace(/\.desktop$/, ""), String(it.name).toLowerCase()]
    var tl = Hyprland.toplevels.values
    for (var i = 0; i < tl.length; i++) {
      var o = tl[i].lastIpcObject || {}
      var cls = String(o["class"] || "").toLowerCase()
      if (cls && keys.indexOf(cls) !== -1) return tl[i]
    }
    return null
  }
  function activate(it) {
    if (it.id === "claude-code") { Quickshell.execDetached(["omarchy-agent", "--pick"]); return }
    var w = windowFor(it)
    if (w) {
      var t = "window = \"address:0x" + w.address + "\""
      Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ " + t + " })"])
      return
    }
    if (root.appLibrary) root.appLibrary.launch(it.entry.id, it.entry.name)
    else Quickshell.execDetached(["gtk-launch", it.entry.id])
  }

  implicitWidth: row.implicitWidth
  implicitHeight: root.bar ? root.bar.barSize : Style.space(28)
  visible: items.length > 0

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    Repeater {
      model: root.items
      Item {
        id: slot
        required property var modelData
        width: Style.space(28); height: root.implicitHeight
        Rectangle {
          anchors.centerIn: parent
          width: Style.space(24); height: Style.space(22); radius: Style.space(6)
          color: root.tint
          opacity: m.containsMouse ? 0.1 : 0
          Behavior on opacity { NumberAnimation { duration: Style.duration(100) } }
        }
        Image {
          anchors.centerIn: parent
          source: slot.modelData.icon
          width: Style.space(16); height: width
          sourceSize.width: width * 2; sourceSize.height: height * 2
          fillMode: Image.PreserveAspectFit
          smooth: true; mipmap: true
          scale: m.pressed ? 0.82 : (m.containsMouse ? 1.1 : 1)
          Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        }
        MouseArea {
          id: m
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onEntered: if (root.bar) root.bar.showTooltip(slot, slot.modelData.name)
          onExited: if (root.bar) root.bar.hideTooltip(slot)
          onClicked: function(mouse) {
            if (root.bar) root.bar.hideTooltip(slot)
            if (mouse.button === Qt.RightButton) Quickshell.execDetached(["omarchy-shell", "liquid-glass.settings", "openPage", "shortcuts"])
            else root.activate(slot.modelData)
          }
        }
      }
    }
  }
}
