import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================================
// Liquid Glass — Finder (macOS 27 « Golden Gate »).
// Un seul processus pour toutes les fenêtres du Finder : `liquid-glass finder
// [dossier]` appelle l'IPC « finder » s'il tourne déjà, sinon le démarre. Le
// processus se ferme avec sa dernière fenêtre (pas de RAM utilisée hors usage).
// ============================================================================
ShellRoot {
  id: root
  property int nextId: 1
  property var lastWin: null
  ListModel { id: wins }

  function expand(p) {
    p = String(p || "").trim()
    var home = Quickshell.env("HOME")
    if (p === "" ) return home
    if (p === "~") return home
    if (p.indexOf("~/") === 0) return home + p.slice(1)
    if (p.indexOf("file://") === 0) p = decodeURIComponent(p.slice(7))
    return p
  }
  function openWindow(path) {
    var p = String(path || "")
    wins.append({ wid: root.nextId++, start: (p === "recents" || p === "apps" || p === "trash" || p === "goto") ? p : root.expand(p) })
  }
  function closeWindow(wid) {
    for (var i = 0; i < wins.count; i++) if (wins.get(i).wid === wid) { wins.remove(i); break }
    if (wins.count === 0) Qt.quit()
  }

  Component.onCompleted: openWindow(Quickshell.env("LG_FINDER_PATH") || "")

  IpcHandler {
    target: "finder"
    function open(path: string): void { root.openWindow(path) }
    function count(): int { return wins.count }
    // Présentation de la dernière fenêtre : icons | list | columns | gallery
    function view(v: string): void { if (root.lastWin) root.lastWin.view = v }
    // Menu « Aller » de la barre : navigue dans la dernière fenêtre utilisée.
    function go(path: string): void {
      if (root.lastWin) root.lastWin.navigate(path)
      else root.openWindow(path)
    }
  }

  Instantiator {
    model: wins
    delegate: FinderWindow {
      id: fw
      required property int wid
      required property string start
      startPath: start
      onCloseRequested: root.closeWindow(wid)
      onNewWindowRequested: function(p) { root.openWindow(p) }
      onWinActiveChanged: if (winActive) root.lastWin = fw
      Component.onCompleted: root.lastWin = fw
      Component.onDestruction: if (root.lastWin === fw) root.lastWin = null
    }
  }
}
