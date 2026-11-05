import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Calc.js" as Calc

// ============================================================================
// Liquid Glass — Spotlight (SUPER+Espace).
//   • Calculatrice : « 12*(3+4) » → Entrée copie le résultat
//   • Applications : index et recherche floue d'Omarchy (appLibrary)
//   • Commandes : verrouiller, mode sombre, captures, karaoké, réglages…
//   • Fichiers : fd dans ~ (sans shell, motif littéral, 8 résultats max)
//   • « > commande » : exécute dans un terminal ; sinon recherche web en dernier recours
// Navigation : ↑/↓, Entrée, Échap. Ctrl+Entrée sur un fichier : l'afficher dans Fichiers.
// ============================================================================
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string home: Quickshell.env("HOME")
  readonly property var appLib: shell ? shell.appLibrary : null
  readonly property string uiFont: "Inter"
  readonly property string iconFont: Style.font.family
  readonly property color fg: Commons.Color.menu.text
  readonly property color accent: Commons.Color.accent
  function g(cp) { return String.fromCodePoint(cp) }

  property string query: ""
  property var results: []
  property int selected: 0
  property var fileHits: []

  // --------------------------------------------------------------- commandes
  // [titre, sous-titre, glyphe, argv, mots-clés]
  readonly property var commands: [
    ["Verrouiller l'écran", "Système", 0xF033E, ["omarchy-shell", "lock", "lock"], "lock verrou"],
    ["Basculer clair / sombre", "Apparence", 0xF0594, ["liquid-glass", "mode", "toggle"], "dark light theme thème nuit jour"],
    ["Réglages Liquid Glass", "Apparence", 0xF0493, ["omarchy-shell", "liquid-glass.settings", "toggle"], "settings préférences config"],
    ["Raccourcis clavier", "Aide", 0xF030C, ["omarchy-shell", "liquid-glass.cheatsheet", "toggle"], "keybindings shortcuts aide"],
    ["Centre de contrôle", "Système", 0xF0521, ["omarchy-shell", "liquid-glass.control", "toggle"], "wifi bluetooth volume luminosité"],
    ["Mission Control", "Fenêtres", 0xF0570, ["omarchy-shell", "shell", "toggle", "liquid-glass.mission"], "expose exposé fenêtres overview"],
    ["Capture d'écran (zone)", "Capture", 0xF0100, ["omarchy", "capture", "screenshot", "region"], "screenshot capture"],
    ["Capture d'écran (plein écran)", "Capture", 0xF0100, ["omarchy", "capture", "screenshot", "fullscreen"], "screenshot capture"],
    ["Enregistrer l'écran", "Capture", 0xF044A, ["omarchy", "capture", "screenrecording"], "record vidéo"],
    ["Paroles en karaoké", "Musique", 0xF0387, ["omarchy-shell", "liquid-glass.spotify", "karaoke"], "lyrics spotify chanson"],
    ["Paroles sur le bureau", "Musique", 0xF0387, ["omarchy-shell", "liquid-glass.spotify", "desktop"], "lyrics spotify"],
    ["Widget de paroles", "Musique", 0xF0387, ["omarchy-shell", "liquid-glass.spotify", "widget"], "lyrics spotify"],
    ["Ne pas déranger", "Notifications", 0xF009B, ["omarchy-shell", "notifications", "toggleDnd"], "dnd concentration focus"],
    ["Night Shift", "Affichage", 0xF0594, ["omarchy-shell", "nightlight", "toggle"], "nightlight lumière nocturne"],
    ["Changer de thème Omarchy", "Apparence", 0xF03D8, ["omarchy-shell", "shell", "toggle", "omarchy.menu", "{\"menu\":\"theme\"}"], "theme"],
    ["Moniteur d'activité", "Système", 0xF0128, ["omarchy-launch-or-focus-tui", "btop"], "btop processus cpu ram"],
    ["Mettre en veille", "Alimentation", 0xF04B2, ["systemctl", "suspend"], "suspend sleep"],
    ["Redémarrer", "Alimentation", 0xF0709, ["omarchy", "system", "reboot"], "reboot restart"],
    ["Éteindre", "Alimentation", 0xF0425, ["omarchy", "system", "shutdown"], "shutdown poweroff"],
    ["Fermer la session", "Alimentation", 0xF0343, ["omarchy", "system", "logout"], "logout déconnexion"]
  ]

  function fold(s) {
    return String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
  }
  function matches(hay, q) {
    var words = fold(q).split(/\s+/).filter(function(w) { return w !== "" })
    var h = fold(hay)
    for (var i = 0; i < words.length; i++) if (h.indexOf(words[i]) === -1) return false
    return words.length > 0
  }

  // --------------------------------------------------------------- résultats
  function rebuild() {
    var q = query.trim()
    var out = []
    if (q === "") { results = []; selected = 0; return }

    if (q.charAt(0) === ">") {
      var cmd = q.slice(1).trim()
      if (cmd !== "") out.push({ section: "Terminal", kind: "run", title: cmd, sub: "Exécuter dans le terminal", glyph: 0xF018D, cmd: cmd })
      results = out; selected = 0; return
    }

    var v = Calc.evaluate(q)
    if (v !== null) out.push({ section: "Calculatrice", kind: "calc", title: "= " + Calc.format(v), sub: q + "  ·  Entrée pour copier", glyph: 0xF00EC, value: Calc.plain(v) })

    if (appLib) {
      var apps = appLib.sortedEntries(q) || []
      for (var i = 0; i < apps.length && i < 6; i++) {
        var e = apps[i].entry || apps[i]   // sortedEntries renvoie des lignes {entry, score, name}
        out.push({ section: "Applications", kind: "app", title: appLib.entryName(e), sub: appLib.entrySubtext(e) || "", icon: appLib.iconSource(e.icon), entry: e })
      }
    }

    var nc = 0
    for (var c = 0; c < commands.length && nc < 4; c++) {
      var cm = commands[c]
      if (matches(cm[0] + " " + cm[1] + " " + cm[4], q)) {
        out.push({ section: "Commandes", kind: "cmd", title: cm[0], sub: cm[1], glyph: cm[2], argv: cm[3] })
        nc++
      }
    }

    for (var f = 0; f < fileHits.length; f++) {
      var path = fileHits[f]
      var isDir = path.charAt(path.length - 1) === "/"
      var clean = isDir ? path.slice(0, -1) : path
      var name = clean.slice(clean.lastIndexOf("/") + 1)
      var dir = clean.slice(0, clean.lastIndexOf("/")).replace(home, "~")
      out.push({ section: "Fichiers", kind: "file", title: name, sub: dir, glyph: isDir ? 0xF024B : 0xF0214, path: clean })
    }

    out.push({ section: "Web", kind: "web", title: "Rechercher « " + q + " » sur le web", sub: "DuckDuckGo", glyph: 0xF059F, q: q })
    results = out
    if (selected >= out.length) selected = 0
  }

  onQueryChanged: {
    selected = 0
    fileHits = []
    rebuild()
    if (query.trim().length >= 2 && query.trim().charAt(0) !== ">") fileTimer.restart()
    else { fileTimer.stop(); fdProc.running = false }
  }

  Timer {
    id: fileTimer
    interval: 160
    onTriggered: {
      if (fdProc.running) fdProc.running = false
      fdProc.forQuery = root.query
      fdProc.command = ["fd", "--fixed-strings", "--ignore-case", "--max-results", "8",
                        "--max-depth", "7", "--exclude", "node_modules", "--", root.query.trim(), root.home]
      fdProc.running = true
    }
  }
  Process {
    id: fdProc
    property string forQuery: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (fdProc.forQuery !== root.query) return
        var lines = text.split("\n").filter(function(l) { return l !== "" })
        root.fileHits = lines.slice(0, 8)
        root.rebuild()
      }
    }
  }

  function activate(i, alt) {
    var r = results[i]
    if (!r) return
    dismiss()
    if (r.kind === "app") appLib.launch(r.entry.id, r.title)
    else if (r.kind === "cmd") Util.execArgv(r.argv)
    else if (r.kind === "calc") Util.execArgv(["wl-copy", "--", r.value])
    else if (r.kind === "file") {
      if (alt) Util.execArgv(["nautilus", "--select", r.path])
      else Util.execArgv(["xdg-open", r.path])
    }
    else if (r.kind === "web") Util.execArgv(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(r.q)])
    else if (r.kind === "run") Util.execArgv(["xdg-terminal-exec", "bash", "-c", r.cmd + "; echo; read -n1 -rsp 'Appuie sur une touche pour fermer…'"])
  }

  function move(d) {
    if (results.length === 0) return
    selected = (selected + d + results.length) % results.length
    list.positionViewAtIndex(selected, ListView.Contain)
  }

  // --------------------------------------------------------------- ouverture
  function open(payloadJson) {
    query = ""
    results = []
    selected = 0
    opened = true
    Qt.callLater(function() { input.forceActiveFocus() })
  }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "liquid-glass.spotlight")
  }
  function toggle() { if (opened) dismiss(); else open("") }

  // --------------------------------------------------------------- fenêtre
  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-spotlight"

    // Voile quasi invisible (sous le seuil de flou) : un clic à côté ferme.
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.03) }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: Math.min(Style.space(680), win.width - 48)
      height: Style.space(60) + (root.results.length > 0 ? Math.min(list.contentHeight, Style.space(430)) + Style.space(10) : 0)
      x: Math.round((win.width - width) / 2)
      y: Math.round(win.height * 0.22)
      radius: Style.space(22)
      color: Commons.Color.menu.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, 1)
      Behavior on height { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }

      scale: root.opened ? 1 : 0.96
      opacity: root.opened ? 1 : 0
      Behavior on scale { SpringAnimation { spring: 4; damping: 0.42; epsilon: 0.002 } }

      MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

      // Champ de recherche
      Item {
        id: header
        width: parent.width
        height: Style.space(60)
        Text {
          id: lens
          x: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.g(0xF0349)
          font.family: root.iconFont
          font.pixelSize: Style.space(22)
          color: root.fg
          opacity: 0.55
        }
        TextInput {
          id: input
          anchors.left: lens.right
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter
          font.family: root.uiFont
          font.pixelSize: Style.space(24)
          font.weight: Font.Light
          color: root.fg
          selectionColor: root.accent
          selectedTextColor: "#ffffff"
          clip: true
          text: root.query
          onTextEdited: root.query = text
          Keys.onPressed: function(ev) {
            if (ev.key === Qt.Key_Escape) { if (root.query !== "") root.query = ""; else root.dismiss(); ev.accepted = true }
            else if (ev.key === Qt.Key_Down || (ev.key === Qt.Key_Tab)) { root.move(1); ev.accepted = true }
            else if (ev.key === Qt.Key_Up || ev.key === Qt.Key_Backtab) { root.move(-1); ev.accepted = true }
            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
              root.activate(root.selected, (ev.modifiers & Qt.ControlModifier) !== 0); ev.accepted = true
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            textFormat: Text.PlainText
            text: "Recherche Spotlight"
            font: input.font
            color: root.fg
            opacity: 0.38
          }
        }
      }

      Rectangle {
        visible: root.results.length > 0
        anchors.top: header.bottom
        x: Style.space(14)
        width: parent.width - Style.space(28)
        height: 1
        color: root.fg
        opacity: 0.1
      }

      ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: Style.space(6)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(4)
        x: Style.space(8)
        width: parent.width - Style.space(16)
        clip: true
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
          id: row
          required property var modelData
          required property int index
          readonly property bool hot: index === root.selected
          // En-tête de section dessiné par la première ligne de chaque groupe
          // (ListView.section ne fonctionne pas avec un modèle tableau JS).
          readonly property bool firstOfSection: index === 0 || root.results[index - 1].section !== modelData.section
          readonly property real headerH: firstOfSection ? Style.space(22) : 0
          width: list.width
          height: Style.space(42) + headerH

          Text {
            visible: row.firstOfSection
            x: Style.space(12)
            y: Style.space(5)
            textFormat: Text.PlainText
            text: row.modelData.section
            font.family: root.uiFont
            font.pixelSize: Style.space(11)
            font.weight: Font.DemiBold
            color: root.fg
            opacity: 0.45
          }

          Rectangle {
            anchors.fill: parent
            anchors.topMargin: row.headerH
            radius: Style.space(10)
            color: root.accent
            opacity: row.hot ? 0.95 : (rowMouse.containsMouse ? 0.12 : 0)
            Behavior on opacity { NumberAnimation { duration: Style.duration(70) } }
          }

          Item {
            id: ico
            x: Style.space(10)
            y: row.headerH + (Style.space(42) - height) / 2
            width: Style.space(28); height: width
            Image {
              anchors.fill: parent
              visible: row.modelData.kind === "app"
              source: row.modelData.kind === "app" ? row.modelData.icon : ""
              sourceSize: Qt.size(64, 64)
              smooth: true
              asynchronous: true
            }
            Text {
              anchors.centerIn: parent
              visible: row.modelData.kind !== "app"
              textFormat: Text.PlainText
              text: row.modelData.glyph ? root.g(row.modelData.glyph) : ""
              font.family: root.iconFont
              font.pixelSize: Style.space(19)
              color: row.hot ? "#ffffff" : root.fg
              opacity: row.hot ? 1 : 0.75
            }
          }

          Column {
            anchors.left: ico.right
            anchors.leftMargin: Style.space(12)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: ico.verticalCenter
            spacing: 1
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: row.modelData.title
              elide: Text.ElideRight
              font.family: root.uiFont
              font.pixelSize: row.modelData.kind === "calc" ? Style.space(17) : Style.space(14)
              font.weight: row.modelData.kind === "calc" ? Font.DemiBold : Font.Medium
              color: row.hot ? "#ffffff" : root.fg
            }
            Text {
              width: parent.width
              visible: text !== ""
              textFormat: Text.PlainText
              text: row.modelData.sub || ""
              elide: Text.ElideMiddle
              font.family: root.uiFont
              font.pixelSize: Style.space(11.5)
              color: row.hot ? "#ffffff" : root.fg
              opacity: row.hot ? 0.8 : 0.5
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            anchors.topMargin: row.headerH
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(m) { root.activate(row.index, (m.modifiers & Qt.ControlModifier) !== 0) }
          }
        }
      }
    }
  }
}
