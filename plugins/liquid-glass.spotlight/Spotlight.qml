import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Calc.js" as Calc
import "Units.js" as Units
import "Mac.js" as Mac
import "T.js" as T

// ============================================================================
// Liquid Glass — Spotlight (SUPER+Espace).
//   • Calculatrice : « 12*(3+4) » → Entrée copie le résultat
//   • Applications : index et recherche floue d'Omarchy (appLibrary)
//   • Commandes : verrouiller, mode sombre, captures, karaoké, réglages…
//   • Fichiers : fd dans ~ (sans shell, motif littéral, 8 résultats max)
//   • Conversions : « 10 km en miles », « 72 f en c », « 3 go en mo »
//   • Sites : « yt … », « wiki … », « gh … », « sp … » (Spotify), « maps … », « aw … »…
//   • Champ vide : éléments ouverts récemment (comme l'historique de Spotlight)
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
  // Mode filtré (boutons à droite de la barre, Ctrl+1…5) : "" = tout.
  property string mode: ""
  // [id, nom, glyphe, indication du champ]
  readonly property var modes: [
    ["apps", "Applications", 0xF003B, T.t("Rechercher des applications")],
    ["files", T.t("Fichiers"), 0xF024B, T.t("Rechercher des fichiers")],
    ["actions", T.t("Actions"), 0xF140B, T.t("Rechercher des actions")],
    ["clipboard", T.t("Presse-papiers"), 0xF014F, T.t("Rechercher dans le presse-papiers")],
    ["emoji", T.t("Émojis"), 0xF0785, T.t("Rechercher des émojis")]
  ]
  function modeInfo(id) { for (var i = 0; i < modes.length; i++) if (modes[i][0] === id) return modes[i]; return null }
  function setMode(id) {
    mode = (mode === id) ? "" : id
    selected = 0
    fileHits = []
    rebuild()
    if (query.trim().length >= 2 || mode === "files") fileTimer.restart()
    input.forceActiveFocus()
  }
  onModeChanged: if (mode === "clipboard") clipFile.reload()

  // Historique du presse-papiers d'Omarchy (texte et images).
  property var clipHistory: []
  FileView {
    id: clipFile
    path: root.home + "/.local/state/omarchy/clipboard-history.json"
    printErrors: false
    onLoaded: { try { root.clipHistory = JSON.parse(text()) || [] } catch (e) { root.clipHistory = [] } }
  }
  // Émojis d'Omarchy (même liste que son sélecteur) ; insérés dans l'app active.
  property var emojis: []
  FileView {
    path: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/shell/plugins/emojis/emojis.json"
    printErrors: false
    onLoaded: { try { root.emojis = JSON.parse(text()) || [] } catch (e) { root.emojis = [] } }
  }
  property var results: []
  property int selected: 0
  property var fileHits: []

  // --------------------------------------------------------------- commandes
  // [titre, sous-titre, glyphe, argv, mots-clés]
  readonly property var commands: [
    [T.t("Verrouiller l'écran"), T.t("Système"), 0xF033E, ["omarchy-shell", "lock", "lock"], "lock verrou"],
    [T.t("Basculer clair / sombre"), T.t("Apparence"), 0xF0594, ["liquid-glass", "mode", "toggle"], "dark light theme thème nuit jour"],
    [T.t("Réglages Liquid Glass"), T.t("Apparence"), 0xF0493, ["omarchy-shell", "liquid-glass.settings", "toggle"], "settings préférences config"],
    [T.t("Raccourcis clavier"), T.t("Aide"), 0xF030C, ["omarchy-shell", "liquid-glass.cheatsheet", "toggle"], "keybindings shortcuts aide"],
    [T.t("Centre de contrôle"), T.t("Système"), 0xF0521, ["omarchy-shell", "liquid-glass.control", "toggle"], "wifi bluetooth volume luminosité"],
    ["Mission Control", T.t("Fenêtres"), 0xF0570, ["omarchy-shell", "shell", "toggle", "liquid-glass.mission"], "expose exposé fenêtres overview"],
    [T.t("En veille (StandBy)"), T.t("Système"), 0xF0150, ["omarchy-shell", "liquid-glass.standby", "toggle"], "standby veille horloge nuit chevet"],
    [T.t("Modifier les widgets"), T.t("Bureau"), 0xF0570, ["omarchy-shell", "liquid-glass.widgets", "edit"], "widgets éditer taille supprimer"],
    [T.t("Capture d'écran (zone)"), T.t("Capture"), 0xF0100, ["omarchy", "capture", "screenshot", "region"], "screenshot capture"],
    [T.t("Capture d'écran (plein écran)"), T.t("Capture"), 0xF0100, ["omarchy", "capture", "screenshot", "fullscreen"], "screenshot capture"],
    [T.t("Enregistrer l'écran"), T.t("Capture"), 0xF044A, ["omarchy", "capture", "screenrecording"], "record vidéo"],
    [T.t("Paroles en karaoké"), T.t("Musique"), 0xF0387, ["omarchy-shell", "liquid-glass.spotify", "karaoke"], "lyrics spotify chanson"],
    [T.t("Paroles sur le bureau"), T.t("Musique"), 0xF0387, ["omarchy-shell", "liquid-glass.spotify", "desktop"], "lyrics spotify"],
    ["Widget de paroles", T.t("Musique"), 0xF0387, ["omarchy-shell", "liquid-glass.spotify", "widget"], "lyrics spotify"],
    [T.t("Ne pas déranger"), "Notifications", 0xF009B, ["omarchy-shell", "notifications", "toggleDnd"], "dnd concentration focus"],
    ["Lecture / Pause", T.t("Musique"), 0xF040A, ["omarchy-shell", "liquid-glass.spotify", "playPause"], "play pause musique spotify lecture"],
    [T.t("Morceau suivant"), T.t("Musique"), 0xF04AD, ["omarchy-shell", "liquid-glass.spotify", "next"], "next suivant skip musique"],
    [T.t("Morceau précédent"), T.t("Musique"), 0xF04AE, ["omarchy-shell", "liquid-glass.spotify", "previous"], "previous précédent musique"],
    [T.t("Historique du presse-papiers"), T.t("Système"), 0xF014F, ["omarchy-shell", "shell", "toggle", "omarchy.clipboard"], "clipboard copier coller presse"],
    [T.t("Émojis"), T.t("Saisie"), 0xF0785, ["omarchy-shell", "shell", "toggle", "omarchy.emojis"], "emoji smiley caractères"],
    ["Night Shift", T.t("Affichage"), 0xF0594, ["omarchy-shell", "nightlight", "toggle"], "nightlight lumière nocturne"],
    [T.t("Changer de thème Omarchy"), T.t("Apparence"), 0xF03D8, ["omarchy-shell", "shell", "toggle", "omarchy.menu", "{\"menu\":\"theme\"}"], "theme"],
    [T.t("Moniteur d'activité"), T.t("Système"), 0xF0128, ["omarchy-launch-or-focus-tui", "btop"], "btop processus cpu ram"],
    [T.t("Mettre en veille"), T.t("Alimentation"), 0xF04B2, ["systemctl", "suspend"], "suspend sleep"],
    [T.t("Redémarrer"), T.t("Alimentation"), 0xF0709, ["omarchy", "system", "reboot"], "reboot restart"],
    [T.t("Éteindre"), T.t("Alimentation"), 0xF0425, ["omarchy", "system", "shutdown"], "shutdown poweroff"],
    [T.t("Fermer la session"), T.t("Alimentation"), 0xF0343, ["omarchy", "system", "logout"], "logout déconnexion"]
  ]

  // ------------------------------------------------------------------ sites
  // [mots-clés, nom, adresse (la recherche est ajoutée encodée), glyphe]
  readonly property var sites: [
    [["yt", "youtube"], "YouTube", "https://www.youtube.com/results?search_query=", 0xF05C3],
    [["wiki", "wp", "wikipedia", "wikipédia"], T.t("Wikipédia"), "https://fr.wikipedia.org/w/index.php?search=", 0xF05AC],
    [["gh", "github"], "GitHub", "https://github.com/search?q=", 0xF02A4],
    [["sp", "spotify"], "Spotify", "spotify:search:", 0xF04C7],
    [["maps", "carte", "plan"], "OpenStreetMap", "https://www.openstreetmap.org/search?query=", 0xF034D],
    [["g", "google"], "Google", "https://www.google.com/search?q=", 0xF02AD],
    [["aw", "archwiki"], "ArchWiki", "https://wiki.archlinux.org/index.php?search=", 0xF059F],
    [["aur"], "AUR", "https://aur.archlinux.org/packages?K=", 0xF059F],
    [["def", "dico", "wiktionnaire"], T.t("Wiktionnaire"), "https://fr.wiktionary.org/w/index.php?search=", 0xF059F]
  ]
  function siteFor(q) {
    var sp = q.indexOf(" ")
    if (sp <= 0) return null
    var key = q.slice(0, sp).toLowerCase(), rest = q.slice(sp + 1).trim()
    if (rest === "") return null
    for (var i = 0; i < sites.length; i++)
      if (sites[i][0].indexOf(key) !== -1) return { site: sites[i], q: rest }
    return null
  }

  // ---------------------------------------------------------------- récents
  property var recents: []
  FileView {
    id: recentsFile
    path: root.home + "/.cache/liquid-glass/spotlight-recents.json"
    printErrors: false
    atomicWrites: true
    onLoaded: { try { root.recents = JSON.parse(text()) || [] } catch (e) { root.recents = [] } }
  }
  function remember(r) {
    if (r.kind === "clip") return
    var e = null
    if (r.kind === "app") e = { kind: "app", title: r.title, sub: r.sub, id: r.entry.id, iconName: r.entry.icon || "" }
    else if (r.kind === "cmd") e = { kind: "cmd", title: r.title, sub: r.sub, glyph: r.glyph, argv: r.argv }
    else if (r.kind === "file") e = { kind: "file", title: r.title, sub: r.sub, glyph: r.glyph, path: r.path }
    else if (r.kind === "web") e = { kind: "web", title: r.title, sub: r.sub, glyph: r.glyph, url: r.url }
    if (!e) return
    var key = e.kind + "|" + e.title + "|" + (e.path || e.url || "")
    var list = [e]
    for (var i = 0; i < recents.length && list.length < 8; i++) {
      var o = recents[i]
      if (o.kind + "|" + o.title + "|" + (o.path || o.url || "") !== key) list.push(o)
    }
    recents = list
    recentsFile.setText(JSON.stringify(list))
  }

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
    if (mode !== "") { results = rebuildMode(q); if (selected >= results.length) selected = 0; return }
    if (q === "") {
      // Champ vide : éléments récents.
      for (var ri = 0; ri < recents.length; ri++) {
        var rc = recents[ri]
        var item = { section: T.t("Récents"), kind: rc.kind, title: rc.title, sub: rc.sub || "", glyph: rc.glyph || 0xF02DA, argv: rc.argv, path: rc.path, url: rc.url }
        if (rc.kind === "app") { if (!appLib) continue; item.icon = appLib.iconSource(rc.iconName); item.entry = { id: rc.id, icon: rc.iconName } }
        out.push(item)
      }
      results = out; selected = 0; return
    }

    if (q.charAt(0) === ">") {
      var cmd = q.slice(1).trim()
      if (cmd !== "") out.push({ section: T.t("Terminal"), kind: "run", title: cmd, sub: T.t("Exécuter dans le terminal"), glyph: 0xF018D, cmd: cmd })
      results = out; selected = 0; return
    }

    var site = siteFor(q)
    if (site) out.push({ section: site.site[1], kind: "web", title: T.t("Rechercher « ") + site.q + " »", sub: site.site[1], glyph: site.site[3], url: site.site[2] + encodeURIComponent(site.q) })

    var conv = Units.convert(q)
    if (conv) out.push({ section: T.t("Conversion"), kind: "calc", title: "= " + Calc.format(Math.round(conv.value * 1e4) / 1e4) + " " + conv.unit,
                         sub: Calc.format(conv.input) + " " + conv.fromUnit + T.t("  ·  Entrée pour copier"), glyph: 0xF04E1, value: Calc.plain(Math.round(conv.value * 1e6) / 1e6) })

    var v = conv ? null : Calc.evaluate(q)
    if (v !== null) out.push({ section: T.t("Calculatrice"), kind: "calc", title: "= " + Calc.format(v), sub: q + T.t("  ·  Entrée pour copier"), glyph: 0xF00EC, value: Calc.plain(v) })

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
        out.push({ section: T.t("Commandes"), kind: "cmd", title: cm[0], sub: cm[1], glyph: cm[2], argv: cm[3] })
        nc++
      }
    }

    for (var f = 0; f < fileHits.length; f++) {
      var path = fileHits[f]
      var isDir = path.charAt(path.length - 1) === "/"
      var clean = isDir ? path.slice(0, -1) : path
      var name = clean.slice(clean.lastIndexOf("/") + 1)
      var dir = clean.slice(0, clean.lastIndexOf("/")).replace(home, "~")
      out.push({ section: T.t("Fichiers"), kind: "file", title: name, sub: dir, glyph: isDir ? 0xF024B : 0xF0214, path: clean })
    }

    out.push({ section: "Web", kind: "web", title: T.t("Rechercher « ") + q + T.t(" » sur le web"), sub: "DuckDuckGo", glyph: 0xF059F, url: "https://duckduckgo.com/?q=" + encodeURIComponent(q) })
    results = out
    if (selected >= out.length) selected = 0
  }

  // Résultats d'un mode : une seule catégorie, et du contenu même champ vide.
  function rebuildMode(q) {
    var out = [], i
    if (mode === "apps") {
      if (!appLib) return out
      var apps = appLib.sortedEntries(q) || []
      for (i = 0; i < apps.length && i < 60; i++) {
        var e = apps[i].entry || apps[i]
        out.push({ section: q === "" ? T.t("Toutes les applications") : "Applications", kind: "app", title: appLib.entryName(e), sub: appLib.entrySubtext(e) || "", icon: appLib.iconSource(e.icon), entry: e })
      }
    } else if (mode === "files") {
      for (i = 0; i < fileHits.length; i++) {
        var path = fileHits[i], isDir = path.charAt(path.length - 1) === "/"
        var clean = isDir ? path.slice(0, -1) : path
        out.push({ section: q === "" ? T.t("Modifiés récemment") : T.t("Fichiers"), kind: "file", title: clean.slice(clean.lastIndexOf("/") + 1),
                   sub: clean.slice(0, clean.lastIndexOf("/")).replace(home, "~"), glyph: isDir ? 0xF024B : 0xF0214, path: clean })
      }
    } else if (mode === "actions") {
      for (i = 0; i < commands.length; i++) {
        var cm = commands[i]
        if (q === "" || matches(cm[0] + " " + cm[1] + " " + cm[4], q))
          out.push({ section: cm[1], kind: "cmd", title: cm[0], sub: cm[1], glyph: cm[2], argv: cm[3] })
      }
      out.sort(function(a, b) { return a.section < b.section ? -1 : (a.section > b.section ? 1 : 0) })
    } else if (mode === "clipboard") {
      for (i = 0; i < clipHistory.length && out.length < 40; i++) {
        var c = clipHistory[i]
        if (c.type === "image") {
          if (q !== "" && !matches("image capture " + (c.capturedAt || ""), q)) continue
          out.push({ section: T.t("Presse-papiers"), kind: "clip", title: "Image", sub: c.capturedAt || c.mime || "", glyph: 0xF02E9, image: "file://" + c.path, path: c.path, mime: c.mime || "image/png" })
        } else if (c.text) {
          if (q !== "" && !matches(c.text, q)) continue
          var one = String(c.text).replace(/\s+/g, " ").trim()
          out.push({ section: T.t("Presse-papiers"), kind: "clip", title: one.slice(0, 120), sub: c.text.length + T.t(" caractères  ·  Entrée pour copier"), glyph: 0xF0219, text: c.text })
        }
      }
    } else if (mode === "emoji") {
      for (i = 0; i < emojis.length && out.length < 400; i++) {
        var em = emojis[i]
        if (!em || !em.e) continue
        if (q !== "" && !matches(em.k || "", q)) continue
        out.push({ section: T.t("Émojis"), kind: "emoji", title: String(em.k || ""), sub: "", emoji: em.e })
      }
    }
    return out
  }

  onQueryChanged: {
    selected = 0
    fileHits = []
    rebuild()
    if (mode === "files" || (mode === "" && query.trim().length >= 2 && query.trim().charAt(0) !== ">")) fileTimer.restart()
    else { fileTimer.stop(); fdProc.running = false }
  }

  Timer {
    id: fileTimer
    interval: 160
    onTriggered: {
      if (fdProc.running) fdProc.running = false
      fdProc.forQuery = root.query
      var q = root.query.trim(), n = root.mode === "files" ? "40" : "8"
      if (q === "" && root.mode === "files")
        fdProc.command = ["fd", "--type", "f", "--changed-within", "14d", "--max-results", n, "--max-depth", "4",
                          "--exclude", "node_modules", "--exclude", ".*", ".", root.home]
      else
        fdProc.command = ["fd", "--fixed-strings", "--ignore-case", "--max-results", n,
                          "--max-depth", "7", "--exclude", "node_modules", "--", q, root.home]
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
        root.fileHits = lines.slice(0, root.mode === "files" ? 40 : 8)
        root.rebuild()
      }
    }
  }

  function activate(i, alt) {
    var r = results[i]
    if (!r) return
    dismiss()
    remember(r)
    if (r.kind === "app") appLib.launch(r.entry.id, r.title)
    else if (r.kind === "cmd") Util.execArgv(r.argv)
    else if (r.kind === "calc") Util.execArgv(["wl-copy", "--", r.value])
    else if (r.kind === "emoji") {
      if (alt) Util.execArgv(["wl-copy", "--", r.emoji])
      else Util.execArgv([(Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/bin/omarchy-menu-emoji-insert", r.emoji])
    }
    else if (r.kind === "file") {
      if (alt) Util.execArgv(["nautilus", "--select", r.path])
      else Util.execArgv(["xdg-open", r.path])
    }
    else if (r.kind === "web") Util.execArgv(["xdg-open", r.url])
    else if (r.kind === "clip") {
      if (r.text !== undefined) Util.execArgv(["wl-copy", "--", r.text])
      else Util.execArgv(["sh", "-c", "wl-copy --type \"$1\" < \"$2\"", "_", r.mime, r.path])
    }
    else if (r.kind === "run") Util.execArgv(["xdg-terminal-exec", "bash", "-c", r.cmd + T.t("; echo; read -n1 -rsp 'Appuie sur une touche pour fermer…'")])
  }

  // Émojis : grille (comme le visualiseur de caractères de macOS) ; ↑/↓ changent de ligne.
  readonly property bool emojiGrid: mode === "emoji"
  property int gridCols: 10
  function move(d) {
    if (results.length === 0) return
    selected = (selected + d + results.length) % results.length
    if (emojiGrid) emojiView.positionViewAtIndex(selected, GridView.Contain)
    else list.positionViewAtIndex(selected, ListView.Contain)
  }

  // --------------------------------------------------------------- ouverture
  function open(payloadJson) {
    // Charge utile optionnelle : {"query": "…"} pré-remplit la recherche.
    var pre = "", m = ""
    try {
      var pl = payloadJson ? JSON.parse(payloadJson) : null
      if (pl && typeof pl.query === "string") pre = pl.query.slice(0, 200)
      if (pl && typeof pl.mode === "string" && modeInfo(pl.mode)) m = pl.mode
    } catch (e) {}
    mode = m
    query = pre
    if (m === "files") fileTimer.restart()
    selected = 0
    rebuild()
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
  // Façon macOS Tahoe : une pilule de recherche, à sa droite un groupe de cinq
  // boutons ronds (Applications, Fichiers, Actions, Presse-papiers, Musique),
  // et les résultats dans un panneau de verre séparé, juste dessous.
  OverlayWindow {
    id: win
    shown: root.opened
    WlrLayershell.namespace: "liquid-glass-spotlight"

    // Voile quasi invisible (sous le seuil de flou) : un clic à côté ferme.
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.03) }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    // Comme sur la vidéo de référence : champ ≈ 7,4 × sa hauteur, puis cinq
    // boutons ronds séparés, chacun sa bulle de verre de la hauteur du champ.
    readonly property real barH: Style.space(Mac.spotlight.field)
    readonly property real btn: barH
    readonly property real gap: Style.space(14)
    readonly property real groupW: root.modes.length * btn + (root.modes.length - 1) * gap
    readonly property real pillW: Math.round(barH * 7.4)
    readonly property real totalW: Math.min(pillW + gap + groupW, win.width - 48)

    Item {
      id: stage
      width: win.totalW
      height: win.barH
      x: Math.round((win.width - width) / 2)
      y: Math.round(win.height * 0.2)
      scale: root.opened ? 1 : 0.96
      opacity: root.opened ? 1 : 0
      Behavior on scale { SpringAnimation { spring: 4; damping: 0.42; epsilon: 0.002 } }

      // ---------------------------------------------------- pilule de recherche
      BorderSurface {
        id: pill
        width: win.pillW
        height: win.barH
        radius: height / 2
        color: Commons.Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, 1)
        MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

        Text {
          id: lens
          x: Style.space(20)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.g(0xF0349)
          font.family: root.iconFont
          font.pixelSize: Style.space(21)
          color: root.fg
          opacity: 0.55
        }

        // Pastille du mode actif (clic = retour à « tout »).
        Rectangle {
          id: chip
          visible: false   // la vidéo n'a pas de pastille : le bouton allumé + le texte d'aide suffisent
          anchors.left: lens.right; anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          width: visible ? chipRow.implicitWidth + Style.space(18) : 0
          height: Style.space(28); radius: height / 2
          color: root.accent
          Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Style.space(6)
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: root.mode !== "" ? root.g(root.modeInfo(root.mode)[2]) : ""; font.family: root.iconFont; font.pixelSize: Style.space(13); color: "white" }
            Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: root.mode !== "" ? root.modeInfo(root.mode)[1] : ""; font.family: root.uiFont; font.pixelSize: Style.space(12.5); font.weight: Font.DemiBold; color: "white" }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setMode(root.mode) }
        }

        TextInput {
          id: input
          anchors.left: chip.visible ? chip.right : lens.right
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(22)
          anchors.verticalCenter: parent.verticalCenter
          font.family: root.uiFont
          font.pixelSize: Style.space(22)
          font.weight: Font.Light
          color: root.fg
          selectionColor: root.accent
          selectedTextColor: "#ffffff"
          clip: true
          text: root.query
          onTextEdited: root.query = text
          Keys.onPressed: function(ev) {
            var ctrl = (ev.modifiers & Qt.ControlModifier) !== 0
            if (ctrl && ev.key >= Qt.Key_1 && ev.key <= Qt.Key_5) { root.setMode(root.modes[ev.key - Qt.Key_1][0]); ev.accepted = true }
            else if (ev.key === Qt.Key_Escape) {
              if (root.query !== "") root.query = ""
              else if (root.mode !== "") root.setMode(root.mode)
              else root.dismiss()
              ev.accepted = true
            }
            else if (ev.key === Qt.Key_Backspace && root.query === "" && root.mode !== "") { root.setMode(root.mode); ev.accepted = true }
            else if (ev.key === Qt.Key_Down) { root.move(root.emojiGrid ? root.gridCols : 1); ev.accepted = true }
            else if (ev.key === Qt.Key_Up) { root.move(root.emojiGrid ? -root.gridCols : -1); ev.accepted = true }
            else if (ev.key === Qt.Key_Tab) { root.move(1); ev.accepted = true }
            else if (ev.key === Qt.Key_Backtab) { root.move(-1); ev.accepted = true }
            else if (root.emojiGrid && root.query === "" && (ev.key === Qt.Key_Left || ev.key === Qt.Key_Right)) { root.move(ev.key === Qt.Key_Left ? -1 : 1); ev.accepted = true }
            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
              root.activate(root.selected, ctrl); ev.accepted = true
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            textFormat: Text.PlainText
            text: root.mode !== "" ? root.modeInfo(root.mode)[1] : T.t("Recherche Spotlight")
            font: input.font
            color: root.fg
            opacity: 0.38
          }
        }
      }

      // ---------------------------------------------------- les cinq boutons
      Row {
        id: group
        anchors.left: pill.right
        anchors.leftMargin: win.gap
        spacing: win.gap
        Repeater {
          model: root.modes
          delegate: BorderSurface {
            id: mb
            required property var modelData
            required property int index
            readonly property bool on: root.mode === modelData[0]
            width: win.btn; height: win.btn
            radius: width / 2
            color: mb.on ? root.accent : Commons.Color.menu.background
            borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, 1)
            Behavior on color { ColorAnimation { duration: Style.duration(140) } }
            // Arrivée en cascade, avec rebond, quand Spotlight s'ouvre.
            property real t: 0
            opacity: t
            transform: [
              Scale { origin.x: mb.width / 2; origin.y: mb.height / 2; xScale: (0.4 + 0.6 * mb.t) * (mbMouse.pressed ? 0.88 : (mbMouse.containsMouse ? 1.08 : 1)); yScale: xScale },
              Translate { x: (1 - mb.t) * -Style.space(30) }
            ]
            SequentialAnimation {
              id: mbIn
              PropertyAction { target: mb; property: "t"; value: 0 }
              PauseAnimation { duration: 60 + mb.index * 45 }
              NumberAnimation { target: mb; property: "t"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            }
            Connections { target: root; function onOpenedChanged() { if (root.opened) mbIn.restart() } }
            Component.onCompleted: if (root.opened) mbIn.restart()
            ModeIcon {
              anchors.centerIn: parent
              kind: mb.modelData[0]
              width: Math.round(mb.width * 0.44); height: width
              stroke: 1.6
              color: mb.on ? "#ffffff" : root.fg
              opacity: mb.on ? 1 : 0.78
            }
            MouseArea { id: mbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setMode(mb.modelData[0]) }

            // Info-bulle : nom + raccourci.
            Rectangle {
              visible: mbMouse.containsMouse
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.bottom
              anchors.topMargin: Style.space(10)
              width: tipText.implicitWidth + Style.space(16); height: Style.space(24); radius: Style.space(7)
              color: Commons.Color.tooltip.background
              z: 10
              Text { id: tipText; anchors.centerIn: parent; textFormat: Text.PlainText; text: mb.modelData[1] + "   Ctrl " + (mb.index + 1); font.family: root.uiFont; font.pixelSize: Style.space(11.5); color: Commons.Color.tooltip.text }
            }
          }
        }
      }

      // ---------------------------------------------------- résultats
      BorderSurface {
        id: panel
        anchors.top: pill.bottom
        anchors.topMargin: win.gap
        width: (root.mode === "apps" && root.query.trim() === "") || root.emojiGrid ? win.totalW : win.pillW
        height: root.results.length > 0
          ? (root.emojiGrid ? Math.min(emojiView.contentHeight, Style.space(372)) + Style.space(58)
                            : Math.min(list.contentHeight, Style.space(430)) + Style.space(14))
          : 0
        visible: height > 1
        radius: Style.space(22)
        color: Commons.Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, 1)
        clip: true
        Behavior on height { NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

        // ---- grille d'émojis
        GridView {
          id: emojiView
          visible: root.emojiGrid
          anchors.top: parent.top; anchors.topMargin: Style.space(12)
          anchors.horizontalCenter: parent.horizontalCenter
          width: root.gridCols * cellWidth
          height: Math.min(contentHeight, Style.space(372))
          cellWidth: Math.floor((panel.width - Style.space(24)) / root.gridCols)
          cellHeight: Style.space(46)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.emojiGrid ? root.results : []
          delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool hot: index === root.selected
            width: emojiView.cellWidth; height: emojiView.cellHeight
            Rectangle {
              anchors.centerIn: parent
              width: Style.space(42); height: width; radius: Style.space(11)
              color: root.accent
              opacity: cell.hot ? 0.9 : (cellMouse.containsMouse ? 0.14 : 0)
              Behavior on opacity { NumberAnimation { duration: Style.duration(70) } }
            }
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: cell.modelData.emoji
              font.pixelSize: Style.space(26)
              scale: cellMouse.pressed ? 0.8 : (cellMouse.containsMouse || cell.hot ? 1.15 : 1)
              Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 3 } }
            }
            MouseArea {
              id: cellMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selected = cell.index
              onClicked: function(m) { root.activate(cell.index, (m.modifiers & Qt.ControlModifier) !== 0) }
            }
          }
        }
        // Nom de l'émoji sélectionné + aide.
        Item {
          visible: root.emojiGrid
          anchors.left: parent.left; anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.space(40)
          Rectangle { anchors.top: parent.top; x: Style.space(14); width: parent.width - 2 * x; height: 1; color: root.fg; opacity: 0.08 }
          Text {
            id: emojiName
            x: Style.space(18); anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - emojiHelp.implicitWidth - Style.space(30)
            textFormat: Text.PlainText
            readonly property var cur: root.results[root.selected]
            text: cur && cur.kind === "emoji" ? cur.emoji + "  " + String(cur.title).split(" ").slice(0, 5).join(" ") : ""
            elide: Text.ElideRight
            font.family: root.uiFont; font.pixelSize: Style.space(12.5); font.weight: Font.Medium
            color: root.fg; opacity: 0.8
          }
          Text {
            id: emojiHelp
            anchors.right: parent.right; anchors.rightMargin: Style.space(18); anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: T.t("Entrée : insérer  ·  Ctrl+Entrée : copier")
            font.family: root.uiFont; font.pixelSize: Style.space(11.5)
            color: root.fg; opacity: 0.45
          }
        }

        ListView {
          id: list
          visible: !root.emojiGrid
          anchors.fill: parent
          anchors.topMargin: Style.space(7)
          anchors.bottomMargin: Style.space(7)
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
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
            readonly property bool thumb: modelData.kind === "clip" && !!modelData.image
            readonly property real rowH: thumb ? Style.space(58) : Style.space(42)
            width: list.width
            height: rowH + headerH

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
              y: row.headerH + (row.rowH - height) / 2
              width: row.thumb ? Style.space(64) : Style.space(28); height: row.thumb ? Style.space(44) : width
              Image {
                anchors.fill: parent
                visible: row.modelData.kind === "app" || row.thumb
                source: row.modelData.kind === "app" ? row.modelData.icon : (row.thumb ? row.modelData.image : "")
                sourceSize: row.thumb ? Qt.size(160, 110) : Qt.size(64, 64)
                fillMode: row.thumb ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                smooth: true
                asynchronous: true
              }
              Text {
                anchors.centerIn: parent
                visible: row.modelData.kind === "emoji"
                textFormat: Text.PlainText
                text: row.modelData.emoji || ""
                font.pixelSize: Style.space(22)
              }
              Text {
                anchors.centerIn: parent
                visible: row.modelData.kind !== "app" && row.modelData.kind !== "emoji" && !row.thumb
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
                font.family: row.modelData.kind === "clip" && !row.thumb ? Style.font.family : root.uiFont
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
}
