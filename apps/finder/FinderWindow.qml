import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "T.js" as T
import "Mac.js" as Mac

// Une fenêtre du Finder (macOS 27) : barre latérale bord à bord aux icônes de
// couleur, barre d'outils uniforme (← →, titre, présentation, actions,
// recherche), vues Icônes / Liste / Colonnes / Galerie, barre du chemin et
// d'état, Coup d'œil (Espace), Lire les informations (⌘I), menu contextuel.
FloatingWindow {
  id: w
  signal closeRequested()
  signal newWindowRequested(string path)
  property string startPath: ""
  readonly property bool winActive: frame.activeFocus || searchIn.activeFocus
  function navigate(p) { if (p === "goto") showGo(); else go(p) }

  title: "Finder — " + w.titleText
  implicitWidth: 980
  implicitHeight: 620
  minimumSize: Qt.size(620, 380)
  color: "transparent"

  readonly property string home: Quickshell.env("HOME")

  // ------------------------------------------------------------- apparence
  property bool dark: true
  FileView {
    path: w.home + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: w.dark = !/mode\s*=\s*"light"/.test(text())
    printErrors: false
  }
  readonly property color accent: "#0a84ff"
  readonly property color ink: dark ? Qt.rgba(1, 1, 1, 0.86) : Qt.rgba(0, 0, 0, 0.85)
  readonly property color ink2: dark ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.5)
  readonly property color ink3: dark ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(0, 0, 0, 0.26)
  readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
  readonly property color paper: dark ? Qt.rgba(0.118, 0.118, 0.122, 0.97) : Qt.rgba(1, 1, 1, 0.97)
  readonly property color side: dark ? Qt.rgba(0.17, 0.17, 0.18, 0.84) : Qt.rgba(0.93, 0.93, 0.95, 0.86)
  readonly property color stripe: dark ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(0, 0, 0, 0.03)
  readonly property color glass: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
  readonly property string ui: "Inter"
  readonly property string sym: "Material Symbols Rounded"

  // ------------------------------------------------------------- navigation
  // place : "" (dossier), "recents", "apps", "trash", "search"
  property string cwd: ""
  property string place: ""
  property var backStack: []
  property var fwdStack: []
  property string view: "icons"
  property bool showHidden: false
  property bool pathBar: true
  property bool statusBar: true
  property string sortKey: "name"
  property bool sortRev: false
  property bool foldersFirst: true
  property string query: ""
  property var items: []
  property var sel: ({})
  property int cur: -1
  property int iconSize: 64
  readonly property string trashDir: home + "/.local/share/Trash/files"

  readonly property string titleText: place === "recents" ? T.t("Récents") : place === "apps" ? "Applications"
    : place === "trash" ? T.t("Corbeille") : place === "search" ? T.t("Recherche « ") + query + " »" : nice(cwd)

  function shown(it) { return it.dir && !it.app ? nice(it.path) : it.name }
  function nice(p) {
    if (p === home) return Quickshell.env("USER") || "home"
    if (p === "/") return T.t("Macintosh HD")
    var n = String(p).split("/").pop()
    if (String(p) !== home + "/" + n) return n   // seuls les dossiers du départ sont traduits
    return ({ Desktop: T.t("Bureau"), Downloads: T.t("Téléchargements"), Pictures: T.t("Images"), Music: T.t("Musique"),
              Videos: T.t("Vidéos"), Documents: "Documents", Public: T.t("Public") })[n] || n
  }

  function go(path, noHistory) {
    path = String(path)
    if (path.length > 1 && path.endsWith("/")) path = path.slice(0, -1)
    var to = (path === "recents" || path === "apps" || path === "trash") ? { place: path, cwd: w.cwd } : { place: "", cwd: path }
    if (!noHistory && (to.place !== place || to.cwd !== cwd)) { backStack = backStack.concat([{ place: place, cwd: cwd }]); fwdStack = [] }
    query = ""
    place = to.place
    if (to.place === "trash") cwd = trashDir
    else if (to.place === "") cwd = to.cwd
    sel = ({}); cur = -1
    colPaths = place === "" ? [cwd] : []
    refresh()
  }
  function goBack() { if (!backStack.length) return; var s = backStack[backStack.length - 1]; backStack = backStack.slice(0, -1); fwdStack = fwdStack.concat([{ place: place, cwd: cwd }]); restore(s) }
  function goFwd() { if (!fwdStack.length) return; var s = fwdStack[fwdStack.length - 1]; fwdStack = fwdStack.slice(0, -1); backStack = backStack.concat([{ place: place, cwd: cwd }]); restore(s) }
  function restore(s) { if (s.place) go(s.place, true); else go(s.cwd, true) }
  function up() { if (place !== "" || cwd === "/") return; go(cwd.substring(0, cwd.lastIndexOf("/")) || "/") }

  // ------------------------------------------------------------- contenu
  FolderListModel {
    id: fm
    folder: "file://" + w.cwd
    showDirsFirst: false
    showHidden: w.showHidden
    showDotAndDotDot: false
    sortField: FolderListModel.Unsorted
    onStatusChanged: if (status === FolderListModel.Ready) Qt.callLater(w.rebuild)
    onCountChanged: Qt.callLater(w.rebuild)
  }
  function ext(n) { var i = n.lastIndexOf("."); return i > 0 ? n.slice(i + 1).toLowerCase() : "" }
  function rebuild() {
    if (place !== "" && place !== "trash") return
    var a = []
    for (var i = 0; i < fm.count; i++) {
      var n = fm.get(i, "fileName"), d = fm.get(i, "fileIsDir")
      a.push({ name: n, path: fm.get(i, "filePath"), dir: d, size: d ? -1 : fm.get(i, "fileSize"),
               mtime: fm.get(i, "fileModified").getTime(), ext: d ? "" : ext(n) })
    }
    setItems(a)
  }
  function setItems(a) {
    var rec = place === "recents"   // Récents : toujours du plus récent au plus ancien
    var k = rec ? "date" : sortKey, r = rec ? -1 : (sortRev ? -1 : 1), ff = foldersFirst && !rec
    a.sort(function(x, y) {
      if (ff && x.dir !== y.dir) return x.dir ? -1 : 1
      var c = 0
      if (k === "date") c = x.mtime - y.mtime
      else if (k === "size") c = x.size - y.size
      else if (k === "kind") c = w.kind(x).localeCompare(w.kind(y))
      if (c === 0) c = x.name.localeCompare(y.name, undefined, { numeric: true, sensitivity: "base" })
      return c * r
    })
    items = a
    if (cur >= a.length) cur = a.length - 1
  }
  onSortKeyChanged: setItems(items.slice())
  onSortRevChanged: setItems(items.slice())
  onFoldersFirstChanged: setItems(items.slice())

  function refresh() {
    if (place === "recents") recentsP.running = true
    else if (place === "apps") buildApps()
    else if (place === "search") { searchP.running = false; searchP.running = true }
    else rebuild()
    dfP.running = true
  }

  // Récents (comme le Finder) : documents ouverts récemment (recently-used.xbel, tenu par
  // GTK/Qt/KDE) + fichiers modifiés ces 30 derniers jours dans Bureau, Documents,
  // Téléchargements, Images, Musique et Vidéos (pas les dépôts de code ni les fichiers cachés).
  Process {
    id: recentsP
    command: ["sh", Quickshell.shellDir + "/recents.sh"]
    stdout: StdioCollector { onStreamFinished: if (w.place === "recents") w.setItems(w.parseFind(text)) }
  }
  function parseFind(text) {
    var a = []
    text.split("\n").forEach(function(l) {
      var p = l.split("\t"); if (p.length < 3) return
      var n = p[2].split("/").pop()
      a.push({ name: n, path: p[2], dir: p[1] === "d", size: p[1] === "d" ? -1 : Number(p[1]), mtime: Number(p[0]) * 1000, ext: ext(n) })
    })
    return a
  }
  // Recherche (⌘F) : nom de fichier, dans le dossier courant et ses sous-dossiers.
  property string searchRoot: home
  Process {
    id: searchP
    command: ["sh", "-c", "find \"$1\" -xdev -not -path '*/.*' -iname \"*$2*\" -printf '%T@\\t%s\\t%p\\n' 2>/dev/null | head -400", "sh", w.searchRoot, w.query]
    stdout: StdioCollector { onStreamFinished: if (w.place === "search") w.setItems(w.parseFind(text).map(function(x) { return x })) }
  }
  function search(q) {
    if (q === "") { if (place === "search") go(searchRoot, true); return }
    if (place !== "search") searchRoot = place === "" ? cwd : home
    query = q; place = "search"; sel = ({}); cur = -1
    searchP.running = false; searchP.running = true
  }
  // Applications : les apps installées (fichiers .desktop), comme /Applications.
  function buildApps() {
    var a = []
    var list = DesktopEntries.applications.values
    for (var i = 0; i < list.length; i++) {
      var e = list[i]
      if (e.noDisplay) continue
      a.push({ name: e.name, path: e.id, dir: false, size: -1, mtime: 0, ext: "app", app: e, icon: e.icon })
    }
    sortKey = "name"; setItems(a)
  }
  // La liste des apps se remplit en asynchrone : on reconstruit quand elle arrive.
  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { if (w.place === "apps") w.buildApps() }
  }
  property string freeText: ""
  Process {
    id: dfP
    command: ["sh", "-c", "df -h --output=avail \"$1\" 2>/dev/null | tail -1", "sh", w.place === "" ? w.cwd : w.home]
    stdout: StdioCollector { onStreamFinished: w.freeText = text.trim().replace("G", " Go").replace("T", " To").replace("M", " Mo") }
  }

  // ------------------------------------------------------------- types et icônes
  function kind(it) {
    if (it.app) return "Application"
    if (it.dir) return T.t("Dossier")
    var e = it.ext
    if (["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "svg", "tif", "tiff", "avif"].indexOf(e) >= 0) return T.t("Image ") + e.toUpperCase()
    if (["mp3", "flac", "wav", "ogg", "m4a", "opus", "aac"].indexOf(e) >= 0) return T.t("Audio ") + e.toUpperCase()
    if (["mp4", "mkv", "webm", "mov", "avi"].indexOf(e) >= 0) return T.t("Vidéo ") + e.toUpperCase()
    if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].indexOf(e) >= 0) return T.t("Archive ") + e.toUpperCase()
    if (e === "pdf") return T.t("Document PDF")
    if (["md", "txt", "log", "rst"].indexOf(e) >= 0) return T.t("Texte")
    if (["py", "js", "qml", "sh", "lua", "c", "cpp", "h", "rs", "go", "ts", "json", "toml", "yaml", "yml", "css", "html"].indexOf(e) >= 0) return T.t("Code source ") + e.toUpperCase()
    return e ? T.t("Document ") + e.toUpperCase() : T.t("Document")
  }
  function iconName(it) {
    if (it.app) return it.icon || "application-x-executable"
    if (it.dir) {
      if (it.path === home) return "user-home"
      var n = it.path.split("/").pop()
      return ({ Desktop: "user-desktop", Documents: "folder-documents", Downloads: "folder-download", Music: "folder-music",
                Pictures: "folder-pictures", Videos: "folder-videos", Public: "folder-publicshare", Templates: "folder-templates",
                Work: "folder-development", Projects: "folder-development" })[n] || "folder"
    }
    var e = it.ext
    if (["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "svg", "tif", "tiff", "avif"].indexOf(e) >= 0) return "image-x-generic"
    if (["mp3", "flac", "wav", "ogg", "m4a", "opus", "aac"].indexOf(e) >= 0) return "audio-x-generic"
    if (["mp4", "mkv", "webm", "mov", "avi"].indexOf(e) >= 0) return "video-x-generic"
    if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].indexOf(e) >= 0) return "package-x-generic"
    if (e === "pdf") return "application-pdf"
    if (["doc", "docx", "odt", "rtf", "pages"].indexOf(e) >= 0) return "x-office-document"
    if (["xls", "xlsx", "ods", "csv", "numbers"].indexOf(e) >= 0) return "x-office-spreadsheet"
    if (["ppt", "pptx", "odp", "key"].indexOf(e) >= 0) return "x-office-presentation"
    if (["html", "htm"].indexOf(e) >= 0) return "text-html"
    if (["py", "js", "qml", "sh", "lua", "c", "cpp", "h", "rs", "go", "ts", "json", "toml", "yaml", "yml", "css"].indexOf(e) >= 0) return "text-x-script"
    if (["ttf", "otf", "woff", "woff2"].indexOf(e) >= 0) return "font-x-generic"
    if (e === "iso" || e === "img") return "application-x-cd-image"
    if (e === "desktop") return "application-x-desktop"
    if (e === "appimage" || e === "exe" || e === "bin") return "application-x-executable"
    return "text-x-generic"
  }
  function iconFor(it) { return Quickshell.iconPath(iconName(it), "text-x-generic") }
  function isImage(it) { return !it.dir && ["jpg", "jpeg", "png", "gif", "webp", "bmp", "svg"].indexOf(it.ext) >= 0 }
  function sizeText(b) {
    if (b < 0) return "--"
    if (b < 1000) return b + T.t(" octets")
    var u = [" Ko", " Mo", " Go", " To"], i = -1
    do { b /= 1000; i++ } while (b >= 1000 && i < 3)
    return (b >= 100 ? Math.round(b) : b.toFixed(1).replace(".", ",")) + u[i]
  }
  function dateText(ms) {
    if (!ms) return "--"
    var d = new Date(ms), now = new Date()
    var t = d.toLocaleTimeString(Qt.locale(T.loc), "HH:mm")
    if (d.toDateString() === now.toDateString()) return T.t("Aujourd'hui à ") + t
    var y = new Date(now.getTime() - 86400000)
    if (d.toDateString() === y.toDateString()) return T.t("Hier à ") + t
    return d.toLocaleDateString(Qt.locale(T.loc), "d MMM yyyy") + T.t(" à ") + t
  }

  // ------------------------------------------------------------- sélection
  function selected() { var r = []; for (var i = 0; i < items.length; i++) if (sel[items[i].path]) r.push(items[i]); return r }
  function selPaths() { return selected().map(function(x) { return x.path }) }
  function selCount() { var n = 0; for (var k in sel) if (sel[k]) n++; return n }
  function pick(i, mods) {
    if (i < 0 || i >= items.length) return
    var s = Object.assign({}, sel), p = items[i].path
    if (mods & Qt.ControlModifier || mods & Qt.MetaModifier) s[p] = !s[p]
    else if (mods & Qt.ShiftModifier && cur >= 0) {
      var a = Math.min(cur, i), b = Math.max(cur, i)
      for (var j = a; j <= b; j++) s[items[j].path] = true
    } else { s = {}; s[p] = true }
    sel = s; cur = i
  }
  function selectAll() { var s = {}; items.forEach(function(x) { s[x.path] = true }); sel = s }
  function clearSel() { sel = ({}); cur = -1 }

  // ------------------------------------------------------------- actions
  function run(argv) { Quickshell.execDetached(argv) }
  function sh(script, args) { Quickshell.execDetached(["sh", "-c", script, "sh"].concat(args || [])) }
  function openItem(it) {
    if (!it) return
    if (it.app) { it.app.execute(); return }
    if (it.dir) {
      if (view === "columns" && place === "") return
      go(it.path); return
    }
    run(["xdg-open", it.path])
  }
  function openSelection() { var s = selected(); if (s.length === 1 && s[0].dir) go(s[0].path); else s.forEach(function(x) { if (!x.dir) openItem(x) }) }
  function later(ms) { reloadT.interval = ms; reloadT.restart() }
  Timer { id: reloadT; interval: 300; onTriggered: w.refresh() }
  function trash() {
    var p = selPaths(); if (!p.length) return
    if (place === "trash") {
      ask(T.t("Voulez-vous vraiment supprimer ces éléments ?"), T.t("Cette action est irréversible."), T.t("Supprimer"),
          function() { w.sh("rm -rf -- \"$@\"", p); w.sound("trash"); w.clearSel(); w.later(350) })
      return
    }
    sh("gio trash -- \"$@\"", p)
    sound("trash"); clearSel(); later(350)
  }
  function emptyTrash() {
    ask(T.t("Voulez-vous vraiment supprimer définitivement les éléments de la Corbeille ?"), T.t("Cette action est irréversible."),
        T.t("Vider la Corbeille"), function() { w.sh("gio trash --empty"); w.sound("trash"); w.later(400) })
  }
  function minimize() { run(["liquid-glass", "window", "minimize"]) }
  function zoom() { run(["liquid-glass", "window", "zoom"]) }
  // Alerte façon macOS (feuille au centre de la fenêtre)
  property var askFn: null
  function ask(title, sub, ok, fn) { askBox.title = title; askBox.sub = sub; askBox.ok = ok; askFn = fn; askBox.visible = true }
  function putBack() { sh("for f in \"$@\"; do gio trash --restore \"trash:///$(basename \"$f\")\"; done", selPaths()); later(400) }
  function uniqueName(base) {
    var names = {}; items.forEach(function(x) { names[x.name] = true })
    if (!names[base]) return base
    var dot = base.lastIndexOf("."), stem = dot > 0 ? base.slice(0, dot) : base, e = dot > 0 ? base.slice(dot) : ""
    for (var i = 2; i < 999; i++) if (!names[stem + " " + i + e]) return stem + " " + i + e
    return base
  }
  property string pendingRename: ""
  function newFolder() {
    if (place !== "") return
    var n = uniqueName(T.t("dossier sans titre"))
    sh("mkdir -p -- \"$1\"", [cwd + "/" + n])
    pendingRename = cwd + "/" + n; later(200)
  }
  function duplicate() {
    var src = selPaths()
    src.forEach(function(p) {
      var dot = p.lastIndexOf("."), slash = p.lastIndexOf("/")
      var stem = dot > slash + 1 ? p.slice(0, dot) : p, e = dot > slash + 1 ? p.slice(dot) : ""
      sh("t=\"$2\"; i=2; while [ -e \"$t\" ]; do t=\"$3 $i$4\"; i=$((i+1)); done; cp -a -- \"$1\" \"$t\"", [p, stem + T.t(" copie") + e, stem + T.t(" copie"), e])
    })
    later(400)
  }
  function makeAlias() { selPaths().forEach(function(p) { sh("ln -s -- \"$1\" \"$1 alias\"", [p]) }); later(300) }
  function compress() {
    var p = selPaths(); if (!p.length || place !== "") return
    var name = p.length === 1 ? p[0].split("/").pop() + ".zip" : T.t("Archive.zip")
    sh("cd \"$1\" && shift && out=\"$1\" && shift && zip -qr \"$out\" -- \"$@\"", [cwd, uniqueName(name)].concat(p.map(function(x) { return x.split("/").pop() })))
    later(800)
  }
  function rename(it, n) {
    n = String(n).trim()
    if (!it || n === "" || n === it.name || n.indexOf("/") >= 0) return
    sh("mv -n -- \"$1\" \"$2\"", [it.path, it.path.substring(0, it.path.lastIndexOf("/")) + "/" + n]); later(250)
  }
  // Presse-papiers : interne + text/uri-list pour coller dans les autres apps.
  property var clipPaths: []
  property bool clipCut: false
  function copy(cut) {
    clipPaths = selPaths(); clipCut = !!cut
    if (clipPaths.length) sh("printf 'file://%s\\n' \"$@\" | wl-copy -t text/uri-list", clipPaths)
  }
  function paste(move) {
    if (place !== "" || !clipPaths.length) return
    sh((move || clipCut ? "mv -n" : "cp -an") + " -- \"$@\" \"" + cwd.replace(/"/g, "\\\"") + "/\"", clipPaths)
    if (move || clipCut) clipPaths = []
    later(500)
  }
  function copyPath() { var p = selPaths(); sh("printf '%s' \"$*\" | wl-copy", [p.length ? p.join("\n") : cwd]) }
  function openTerminal() { sh("cd \"$1\" && exec xdg-terminal-exec", [place === "" ? cwd : home]) }
  function sound(n) { if (n === "trash") sh("pw-play /usr/share/sounds/freedesktop/stereo/trash-empty.oga 2>/dev/null || true") }
  function setWallpaper(it) { run(["omarchy", "theme", "bg", "set", it.path]) }

  // Étiquettes (Tags) : couleur par chemin, gardées dans ~/.config/liquid-glass/finder-tags.json.
  readonly property var tagDefs: [["red", T.t("Rouge"), "#ff453a"], ["orange", "Orange", "#ff9f0a"], ["yellow", T.t("Jaune"), "#ffd60a"],
    ["green", T.t("Vert"), "#30d158"], ["blue", T.t("Bleu"), "#0a84ff"], ["purple", T.t("Violet"), "#bf5af2"], ["gray", T.t("Gris"), "#98989d"]]
  function tagColor(id) { for (var i = 0; i < tagDefs.length; i++) if (tagDefs[i][0] === id) return tagDefs[i][2]; return "transparent" }
  property var tags: ({})
  FileView {
    id: tagFile
    path: w.home + "/.config/liquid-glass/finder-tags.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { w.tags = JSON.parse(text()) || {} } catch (e) { w.tags = {} } }
  }
  function toggleTag(id) {
    var t = Object.assign({}, tags)
    selPaths().forEach(function(p) {
      var l = (t[p] || []).slice(), i = l.indexOf(id)
      if (i >= 0) l.splice(i, 1); else l.push(id)
      if (l.length) t[p] = l; else delete t[p]
    })
    tags = t
    tagFile.setText(JSON.stringify(t))
  }
  function tagged(id) {
    var a = []
    for (var p in tags) if (tags[p].indexOf(id) >= 0) { var n = p.split("/").pop(); a.push({ name: n, path: p, dir: false, size: -1, mtime: 0, ext: ext(n) }) }
    return a
  }

  // ------------------------------------------------------------- Colonnes
  property var colPaths: []
  function colOpen(level, it) {
    var c = colPaths.slice(0, level + 1)
    if (it.dir) c.push(it.path)
    colPaths = c
    colPreview = it.dir ? null : it
  }
  property var colPreview: null

  // ------------------------------------------------------------- démarrage
  Component.onCompleted: { if (startPath === "goto") { go(home, true); showGo() } else go(startPath || home, true) }

  // Disques montés (Emplacements).
  property var disks: []
  Process {
    id: lsblkP
    running: true
    command: ["sh", "-c", "lsblk -rno MOUNTPOINT,LABEL,SIZE 2>/dev/null | awk '$1 ~ /^\\/(run\\/media|media|mnt)\\//'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var a = []
        text.split("\n").forEach(function(l) { var p = l.split(" "); if (p[0]) a.push({ path: p[0].replace(/\\x20/g, " "), label: (p[1] || p[0].split("/").pop()).replace(/\\x20/g, " ") }) })
        w.disks = a
      }
    }
  }
  Timer { interval: 5000; repeat: true; running: true; onTriggered: lsblkP.running = true }

  // ============================================================= interface
  Rectangle {
    id: frame
    anchors.fill: parent
    color: w.paper
    radius: 0
    focus: true
    Keys.onPressed: function(ev) { w.keys(ev) }
    Component.onCompleted: forceActiveFocus()

    // ---------------- barre latérale
    Rectangle {
      id: sidebar
      width: 200
      anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
      color: w.side
      Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: w.line }

      // Feux tricolores (fermer, réduire, agrandir) dans la barre latérale.
      Row {
        id: lights
        x: 18; y: 19; spacing: 8
        property bool hover: lightsHover.hovered
        HoverHandler { id: lightsHover }
        Repeater {
          model: [[Mac.window.red, "close"], [Mac.window.yellow, "remove"], [Mac.window.green, "open_in_full"]]
          Rectangle {
            required property var modelData
            required property int index
            width: 12; height: 12; radius: 6
            color: modelData[0]
            border.width: 0.5; border.color: Qt.darker(modelData[0], 1.2)
            Text {
              anchors.centerIn: parent; visible: lights.hover
              text: parent.modelData[1]; font.family: w.sym; font.pixelSize: 9; font.weight: Font.Black; color: Qt.rgba(0, 0, 0, 0.6)
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: if (parent.index === 0) w.closeRequested(); else if (parent.index === 1) w.minimize(); else w.zoom()
            }
          }
        }
      }
      // Glisser le haut de la barre latérale déplace la fenêtre.
      MouseArea {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: 82; height: 52
        onPressed: w.startSystemMove()
        onDoubleClicked: w.zoom()
      }

      Flickable {
        anchors { top: parent.top; topMargin: 52; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: sideCol.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: sideCol
          width: parent.width
          SideHead { label: T.t("Favoris") }
          SideItem { label: T.t("Récents"); glyph: "schedule"; target: "recents" }
          SideItem { label: "Applications"; glyph: "apps"; target: "apps" }
          SideItem { label: T.t("Bureau"); glyph: "desktop_mac"; target: w.home + "/Desktop" }
          SideItem { label: "Documents"; glyph: "description"; target: w.home + "/Documents" }
          SideItem { label: T.t("Téléchargements"); glyph: "download_for_offline"; target: w.home + "/Downloads" }
          SideItem { label: T.t("Images"); glyph: "photo_library"; target: w.home + "/Pictures" }
          SideItem { label: T.t("Musique"); glyph: "music_note"; target: w.home + "/Music" }
          SideItem { label: T.t("Vidéos"); glyph: "movie"; target: w.home + "/Videos" }
          SideItem { label: Quickshell.env("USER") || "home"; glyph: "home"; target: w.home }
          SideItem { label: "Work"; glyph: "code"; target: w.home + "/Work" }
          SideHead { label: T.t("Emplacements") }
          SideItem { label: T.t("Macintosh HD"); glyph: "hard_drive"; target: "/"; tint: w.ink2 }
          Repeater {
            model: w.disks
            SideItem { required property var modelData; label: modelData.label; glyph: "eject"; target: modelData.path; tint: w.ink2; eject: true }
          }
          SideItem { label: T.t("Corbeille"); glyph: "delete"; target: "trash"; tint: w.ink2 }
          SideHead { label: T.t("Tags") }
          Repeater {
            model: w.tagDefs
            SideItem { required property var modelData; label: modelData[1]; dot: modelData[2]; target: "tag:" + modelData[0] }
          }
        }
      }
    }

    component SideHead: Text {
      property string label
      text: label
      leftPadding: 18; topPadding: 12; bottomPadding: 4
      font.family: w.ui; font.pixelSize: 11; font.weight: Font.DemiBold
      color: w.ink3
    }
    component SideItem: Item {
      id: si
      property string label
      property string glyph
      property string target
      property color tint: w.accent
      property string dot: ""
      property bool eject: false
      readonly property bool on: target === "recents" || target === "apps" || target === "trash" ? w.place === target
                                : (target.indexOf("tag:") === 0 ? w.place === target : (w.place === "" && w.cwd === target))
      width: parent ? parent.width : 0; height: 28
      Rectangle {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        radius: 6
        color: si.on ? (w.dark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0, 0, 0, 0.08)) : (siMa.containsMouse ? (w.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)) : "transparent")
      }
      Text {
        visible: si.dot === ""
        x: 20; anchors.verticalCenter: parent.verticalCenter
        text: si.eject ? "hard_drive" : si.glyph; font.family: w.sym; font.pixelSize: 17; color: si.tint
      }
      Rectangle { visible: si.dot !== ""; x: 24; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: si.dot || "transparent" }
      Text {
        x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70; elide: Text.ElideRight
        text: si.label; font.family: w.ui; font.pixelSize: 13; color: w.ink
      }
      Text {
        visible: si.eject; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
        text: "eject"; font.family: w.sym; font.pixelSize: 15; color: w.ink2
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: w.sh("udisksctl unmount -b \"$(findmnt -no SOURCE \"$1\")\"", [si.target]) }
      }
      MouseArea {
        id: siMa; anchors.fill: parent; anchors.rightMargin: si.eject ? 40 : 0; hoverEnabled: true
        onClicked: {
          if (si.target.indexOf("tag:") === 0) { w.backStack = w.backStack.concat([{ place: w.place, cwd: w.cwd }]); w.place = si.target; w.query = ""; w.clearSel(); w.setItems(w.tagged(si.target.slice(4))) }
          else w.go(si.target)
          frame.forceActiveFocus()
        }
      }
    }

    // ---------------- barre d'outils (uniforme, liseré en bas : macOS 27)
    Item {
      id: toolbar
      anchors { left: sidebar.right; right: parent.right; top: parent.top }
      height: 52
      MouseArea { anchors.fill: parent; onPressed: w.startSystemMove(); onDoubleClicked: w.zoom() }
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: w.line }

      // ← →
      Capsule {
        id: navCap
        x: 12; anchors.verticalCenter: parent.verticalCenter
        Btn { glyph: "chevron_left"; enabled: w.backStack.length > 0; onClicked: w.goBack() }
        Btn { glyph: "chevron_right"; enabled: w.fwdStack.length > 0; onClicked: w.goFwd() }
      }
      Text {
        anchors { left: navCap.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: Math.max(60, rightTools.x - x - 12); elide: Text.ElideRight
        text: w.place.indexOf("tag:") === 0 ? w.tagName(w.place.slice(4)) : w.titleText
        font.family: w.ui; font.pixelSize: 15; font.weight: Font.Bold; color: w.ink
      }
      Row {
        id: rightTools
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 8
        Capsule {
          Repeater {
            model: [["icons", "grid_view"], ["list", "view_list"], ["columns", "view_column"], ["gallery", "view_carousel"]]
            Btn { required property var modelData; glyph: modelData[1]; active: w.view === modelData[0]; onClicked: w.view = modelData[0] }
          }
        }
        Capsule {
          Btn { id: sortBtn; glyph: "sort"; onClicked: w.menuAt(sortBtn, "sort") }
          Btn { glyph: "ios_share"; enabled: w.selCount() > 0; onClicked: w.copy(false) }
          Btn { id: tagBtn; glyph: "sell"; enabled: w.selCount() > 0; onClicked: w.menuAt(tagBtn, "tags") }
          Btn { id: moreBtn; glyph: "more_horiz"; onClicked: w.menuAt(moreBtn, "more") }
        }
        // Champ de recherche
        Rectangle {
          width: searchIn.activeFocus || w.query !== "" ? 200 : 32; height: 30; radius: 15
          color: w.glass
          border.width: 1; border.color: w.line
          Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: "search"; font.family: w.sym; font.pixelSize: 17; color: w.ink2 }
          TextInput {
            id: searchIn
            anchors { left: parent.left; leftMargin: 30; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            clip: true
            font.family: w.ui; font.pixelSize: 13; color: w.ink; selectionColor: w.accent
            onTextEdited: searchDeb.restart()
            Keys.onEscapePressed: { text = ""; w.search(""); frame.forceActiveFocus() }
            Keys.onReturnPressed: { w.search(text); frame.forceActiveFocus() }
          }
          MouseArea { anchors.fill: parent; visible: !searchIn.activeFocus; onClicked: searchIn.forceActiveFocus() }
          Timer { id: searchDeb; interval: 350; onTriggered: w.search(searchIn.text) }
        }
      }
    }

    // ---------------- contenu
    Item {
      id: content
      anchors { left: sidebar.right; right: parent.right; top: toolbar.bottom; bottom: footer.top }
      clip: true

      // Vide
      Text {
        anchors.centerIn: parent
        visible: w.items.length === 0 && w.view !== "columns"
        text: w.place === "search" ? T.t("Aucun résultat") : (w.place === "trash" ? T.t("La Corbeille est vide") : T.t("Dossier vide"))
        font.family: w.ui; font.pixelSize: 14; color: w.ink3
      }

      // Clic dans le vide : désélectionne ; clic droit : menu du dossier.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: function(m) { frame.forceActiveFocus(); w.closeMenu(); if (m.button === Qt.RightButton) { w.clearSel(); w.menuAtPoint(content, m.x, m.y, "folder") } else w.clearSel() }
      }

      // ---- Icônes
      GridView {
        id: grid
        visible: w.view === "icons"
        anchors.fill: parent; anchors.margins: 10
        cellWidth: Math.max(96, w.iconSize + 44); cellHeight: w.iconSize + 52
        model: visible ? w.items : []
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: w.cur
        delegate: Item {
          id: gi
          required property var modelData
          required property int index
          readonly property bool on: !!w.sel[modelData.path]
          width: grid.cellWidth; height: grid.cellHeight
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter; y: 2
            width: w.iconSize + 12; height: w.iconSize + 12; radius: 8
            color: gi.on ? (w.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"
          }
          Thumb { anchors.horizontalCenter: parent.horizontalCenter; y: 8; size: w.iconSize; it: gi.modelData }
          Rectangle {
            id: nameBg
            anchors.horizontalCenter: parent.horizontalCenter
            y: w.iconSize + 18
            width: Math.min(parent.width - 8, nameT.implicitWidth + 10); height: nameT.height + 2; radius: 4
            color: gi.on ? w.accent : "transparent"
            Text {
              id: nameT
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.min(implicitWidth, gi.width - 18)
              text: w.shown(gi.modelData)
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
              font.family: w.ui; font.pixelSize: 12
              color: gi.on ? "white" : w.ink
            }
          }
          Row {
            anchors.horizontalCenter: parent.horizontalCenter; y: nameBg.y + nameBg.height + 3; spacing: -3
            Repeater { model: w.tags[gi.modelData.path] || []; Rectangle { required property var modelData; width: 8; height: 8; radius: 4; color: w.tagColor(modelData); border.width: 1; border.color: w.paper } }
          }
          RenameField { it: gi.modelData; anchors.fill: nameBg; anchors.margins: -2 }
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(m) { frame.forceActiveFocus(); w.closeMenu(); if (m.button === Qt.RightButton && w.sel[gi.modelData.path]) { } else w.pick(gi.index, m.modifiers); if (m.button === Qt.RightButton) w.menuAtPoint(gi, m.x, m.y, "item") }
            onDoubleClicked: w.openItem(gi.modelData)
          }
        }
      }

      // ---- Liste
      Item {
        visible: w.view === "list"
        anchors.fill: parent
        Row {
          id: head
          height: 26; x: 0; width: parent.width
          ColHead { label: T.t("Nom"); key: "name"; width: head.width - 470 }
          ColHead { label: T.t("Date de modification"); key: "date"; width: 190 }
          ColHead { label: T.t("Taille"); key: "size"; width: 100 }
          ColHead { label: T.t("Type"); key: "kind"; width: 180 }
        }
        Rectangle { y: 26; width: parent.width; height: 1; color: w.line }
        ListView {
          id: list
          anchors { fill: parent; topMargin: 27 }
          model: parent.visible ? w.items : []
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: w.cur
          delegate: Rectangle {
            id: li
            required property var modelData
            required property int index
            readonly property bool on: !!w.sel[modelData.path]
            width: list.width; height: 24
            radius: 5
            color: on ? w.accent : (index % 2 ? w.stripe : "transparent")
            Row {
              anchors.fill: parent; anchors.leftMargin: 10; spacing: 0
              Item {
                width: head.width - 470 - 10; height: parent.height
                Thumb { x: 0; anchors.verticalCenter: parent.verticalCenter; size: 18; it: li.modelData }
                Text {
                  id: lname
                  x: 26; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 40; elide: Text.ElideMiddle
                  text: w.shown(li.modelData); font.family: w.ui; font.pixelSize: 13; color: li.on ? "white" : w.ink
                }
                Row {
                  x: Math.min(26 + lname.implicitWidth + 6, parent.width - 30); anchors.verticalCenter: parent.verticalCenter; spacing: -3
                  Repeater { model: w.tags[li.modelData.path] || []; Rectangle { required property var modelData; width: 8; height: 8; radius: 4; color: w.tagColor(modelData) } }
                }
                RenameField { it: li.modelData; x: 22; width: parent.width - 30; height: parent.height - 2; anchors.verticalCenter: parent.verticalCenter }
              }
              Text { width: 190; anchors.verticalCenter: parent.verticalCenter; text: w.dateText(li.modelData.mtime); font.family: w.ui; font.pixelSize: 12; color: li.on ? "white" : w.ink2; elide: Text.ElideRight }
              Text { width: 100; anchors.verticalCenter: parent.verticalCenter; text: w.sizeText(li.modelData.size); font.family: w.ui; font.pixelSize: 12; color: li.on ? "white" : w.ink2 }
              Text { width: 170; anchors.verticalCenter: parent.verticalCenter; text: w.kind(li.modelData); font.family: w.ui; font.pixelSize: 12; color: li.on ? "white" : w.ink2; elide: Text.ElideRight }
            }
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onPressed: function(m) { frame.forceActiveFocus(); w.closeMenu(); if (!(m.button === Qt.RightButton && w.sel[li.modelData.path])) w.pick(li.index, m.modifiers); if (m.button === Qt.RightButton) w.menuAtPoint(li, m.x, m.y, "item") }
              onDoubleClicked: w.openItem(li.modelData)
            }
          }
        }
      }

      // ---- Colonnes
      Flickable {
        id: cols
        visible: w.view === "columns"
        anchors.fill: parent
        contentWidth: colRow.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        onContentWidthChanged: if (contentWidth > width) contentX = contentWidth - width
        Row {
          id: colRow
          height: cols.height
          Repeater {
            model: cols.visible ? w.colPaths : []
            Column_ { required property string modelData; required property int index; dir: modelData; level: index }
          }
          // Aperçu du fichier choisi
          Item {
            visible: !!w.colPreview
            width: 260; height: parent.height
            Column {
              anchors.centerIn: parent; spacing: 8; width: parent.width - 30
              Thumb { anchors.horizontalCenter: parent.horizontalCenter; size: 128; it: w.colPreview || ({ name: "", path: "", dir: false, ext: "" }) }
              Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WrapAnywhere; text: w.colPreview ? w.colPreview.name : ""; font.family: w.ui; font.pixelSize: 13; font.weight: Font.DemiBold; color: w.ink }
              Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: w.colPreview ? w.kind(w.colPreview) + " — " + w.sizeText(w.colPreview.size) : ""; font.family: w.ui; font.pixelSize: 11; color: w.ink2 }
            }
          }
        }
      }

      // ---- Galerie
      Item {
        id: gallery
        visible: w.view === "gallery"
        anchors.fill: parent
        // Comme macOS : sans sélection, la galerie montre le premier élément.
        readonly property var it: w.cur >= 0 && w.cur < w.items.length ? w.items[w.cur] : (w.items.length ? w.items[0] : null)
        Item {
          anchors { left: parent.left; right: parent.right; top: parent.top; bottom: strip.top; margins: 16 }
          Image {
            anchors.fill: parent; anchors.bottomMargin: 24
            visible: !!gallery.it && w.isImage(gallery.it)
            source: visible ? "file://" + gallery.it.path : ""
            fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false
            sourceSize: Qt.size(1200, 1200)
          }
          Thumb { anchors.centerIn: parent; visible: !!gallery.it && !w.isImage(gallery.it); size: 160; it: gallery.it || ({ name: "", path: "", dir: false, ext: "" }) }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
            text: gallery.it ? gallery.it.name : ""; font.family: w.ui; font.pixelSize: 13; font.weight: Font.DemiBold; color: w.ink
          }
        }
        ListView {
          id: strip
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
          height: 74
          orientation: ListView.Horizontal
          spacing: 6
          model: gallery.visible ? w.items : []
          currentIndex: Math.max(0, w.cur)
          highlightMoveDuration: 200
          clip: true
          delegate: Rectangle {
            id: gs
            required property var modelData
            required property int index
            width: 70; height: 70; radius: 8
            color: w.cur === index ? Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.35) : "transparent"
            border.width: w.cur === index ? 2 : 0; border.color: w.accent
            Thumb { anchors.centerIn: parent; size: 56; it: gs.modelData }
            MouseArea { anchors.fill: parent; onClicked: function(m) { frame.forceActiveFocus(); w.pick(gs.index, m.modifiers) } onDoubleClicked: w.openItem(gs.modelData) }
          }
        }
        Component.onCompleted: if (w.cur < 0 && w.items.length) w.pick(0, 0)
      }
    }

    // ---------------- barre du chemin et barre d'état
    Rectangle {
      id: footer
      anchors { left: sidebar.right; right: parent.right; bottom: parent.bottom }
      height: (w.pathBar ? 26 : 0) + (w.statusBar ? 24 : 0)
      color: "transparent"
      Rectangle { width: parent.width; height: 1; color: w.line; visible: parent.height > 0 }
      Row {
        visible: w.pathBar
        x: 10; y: 4; height: 20; spacing: 2
        Repeater {
          model: w.crumbs()
          Row {
            required property var modelData
            required property int index
            spacing: 2
            Text { visible: index > 0; text: "chevron_right"; font.family: w.sym; font.pixelSize: 13; color: w.ink3; anchors.verticalCenter: parent.verticalCenter }
            Text { text: w.iconGlyph(modelData.path); font.family: w.sym; font.pixelSize: 13; color: w.accent; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: modelData.label; font.family: w.ui; font.pixelSize: 11; color: w.ink2; anchors.verticalCenter: parent.verticalCenter
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onDoubleClicked: w.go(parent.parent.modelData.path); onClicked: w.go(parent.parent.modelData.path) }
            }
          }
        }
      }
      Text {
        visible: w.statusBar
        anchors.horizontalCenter: parent.horizontalCenter; y: (w.pathBar ? 28 : 4)
        text: (w.selCount() > 0 ? w.selCount() + T.t(" sur ") : "") + w.items.length + (w.items.length > 1 ? T.t(" éléments") : T.t(" élément")) + (w.freeText ? ", " + w.freeText + T.t(" disponibles") : "")
        font.family: w.ui; font.pixelSize: 11; color: w.ink2
      }
      // Taille des icônes (vue Icônes), comme le curseur de la barre d'état.
      Row {
        visible: w.statusBar && w.view === "icons"
        anchors.right: parent.right; anchors.rightMargin: 14; y: (w.pathBar ? 30 : 6); spacing: 6
        Text { text: "photo"; font.family: w.sym; font.pixelSize: 11; color: w.ink2 }
        Rectangle {
          width: 90; height: 4; radius: 2; color: w.line; anchors.verticalCenter: parent.verticalCenter
          Rectangle { width: (w.iconSize - 32) / 96 * parent.width; height: 4; radius: 2; color: w.accent }
          Rectangle { x: (w.iconSize - 32) / 96 * (parent.width) - 6; y: -4; width: 12; height: 12; radius: 6; color: "white"; border.color: w.line }
          MouseArea {
            anchors.fill: parent; anchors.margins: -6
            function set(mx) { w.iconSize = Math.round(32 + Math.max(0, Math.min(1, mx / width)) * 96) }
            onPressed: function(m) { set(m.x) }
            onPositionChanged: function(m) { set(m.x) }
          }
        }
        Text { text: "photo"; font.family: w.sym; font.pixelSize: 16; color: w.ink2 }
      }
    }
    // Bord bas-droit : redimensionner.
    MouseArea {
      anchors { right: parent.right; bottom: parent.bottom }
      width: 14; height: 14; cursorShape: Qt.SizeFDiagCursor
      onPressed: w.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
    }

    // ---------------- Coup d'œil (Espace)
    Rectangle {
      id: ql
      property var it: null
      visible: !!it
      anchors.centerIn: parent
      width: Math.min(parent.width - 80, 760); height: Math.min(parent.height - 60, 520)
      radius: 16
      color: w.dark ? Qt.rgba(0.16, 0.16, 0.17, 0.97) : Qt.rgba(0.97, 0.97, 0.98, 0.98)
      border.width: 1; border.color: w.line
      z: 80
      scale: visible ? 1 : 0.9
      Behavior on scale { SpringAnimation { spring: 4; damping: 0.32 } }
      Text {
        x: 14; y: 10; width: parent.width - 100; elide: Text.ElideMiddle
        text: ql.it ? ql.it.name : ""; font.family: w.ui; font.pixelSize: 13; font.weight: Font.DemiBold; color: w.ink
      }
      Row {
        anchors.right: parent.right; anchors.rightMargin: 10; y: 6; spacing: 6
        Btn { glyph: "open_in_new"; onClicked: { w.openItem(ql.it); ql.it = null } }
        Btn { glyph: "close"; onClicked: ql.it = null }
      }
      Item {
        anchors { fill: parent; topMargin: 40; margins: 14 }
        Image {
          anchors.fill: parent
          visible: !!ql.it && w.isImage(ql.it)
          source: visible ? "file://" + ql.it.path : ""
          fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false
          sourceSize: Qt.size(1400, 1400)
        }
        Flickable {
          anchors.fill: parent
          visible: !!ql.it && ql.text !== ""
          contentHeight: qlText.implicitHeight
          clip: true
          Text { id: qlText; width: parent.width; text: ql.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: w.ink; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText }
        }
        Column {
          anchors.centerIn: parent; spacing: 10
          visible: !!ql.it && !w.isImage(ql.it) && ql.text === ""
          Thumb { anchors.horizontalCenter: parent.horizontalCenter; size: 128; it: ql.it || ({ name: "", path: "", dir: false, ext: "" }) }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: ql.it ? w.kind(ql.it) + " — " + w.sizeText(ql.it.size) : ""; font.family: w.ui; font.pixelSize: 12; color: w.ink2 }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: ql.it ? T.t("Modifié : ") + w.dateText(ql.it.mtime) : ""; font.family: w.ui; font.pixelSize: 12; color: w.ink2 }
        }
      }
      property string text: ""
      Process {
        id: qlP
        stdout: StdioCollector { onStreamFinished: ql.text = text }
      }
      onItChanged: {
        text = ""
        if (it && !it.dir && ["txt", "md", "log", "py", "js", "qml", "sh", "lua", "c", "cpp", "h", "rs", "go", "ts", "json", "toml", "yaml", "yml", "css", "html", "conf", "ini", "csv", "xml", "desktop"].indexOf(it.ext) >= 0) {
          qlP.command = ["head", "-c", "20000", it.path]; qlP.running = true
        }
      }
    }

    // ---------------- Lire les informations (⌘I)
    Rectangle {
      id: info
      property var it: null
      property string du: ""
      visible: !!it
      z: 85
      anchors.right: parent.right; anchors.rightMargin: 20; y: 64
      width: 280; height: infoCol.implicitHeight + 28
      radius: 14
      color: w.dark ? Qt.rgba(0.18, 0.18, 0.19, 0.98) : Qt.rgba(0.98, 0.98, 0.99, 0.99)
      border.width: 1; border.color: w.line
      Column {
        id: infoCol
        x: 14; y: 14; width: parent.width - 28; spacing: 6
        Row {
          spacing: 10
          Thumb { size: 44; it: info.it || ({ name: "", path: "", dir: false, ext: "" }) }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { width: 180; elide: Text.ElideMiddle; text: info.it ? info.it.name : ""; font.family: w.ui; font.pixelSize: 13; font.weight: Font.Bold; color: w.ink }
            Text { text: info.du; font.family: w.ui; font.pixelSize: 11; color: w.ink2 }
          }
        }
        Rectangle { width: parent.width; height: 1; color: w.line }
        InfoRow { k: T.t("Type"); v: info.it ? w.kind(info.it) : "" }
        InfoRow { k: T.t("Taille"); v: info.du }
        InfoRow { k: T.t("Emplacement"); v: info.it ? info.it.path.substring(0, info.it.path.lastIndexOf("/")) : "" }
        InfoRow { k: T.t("Modifié"); v: info.it ? w.dateText(info.it.mtime) : "" }
        Rectangle { width: parent.width; height: 1; color: w.line }
        Row {
          spacing: 6
          Repeater {
            model: w.tagDefs
            Rectangle {
              required property var modelData
              width: 16; height: 16; radius: 8; color: modelData[2]
              border.width: info.it && (w.tags[info.it.path] || []).indexOf(modelData[0]) >= 0 ? 2 : 0; border.color: w.ink
              MouseArea { anchors.fill: parent; onClicked: w.toggleTag(parent.modelData[0]) }
            }
          }
        }
        Text { text: T.t("Fermer"); font.family: w.ui; font.pixelSize: 12; color: w.accent; MouseArea { anchors.fill: parent; onClicked: info.it = null } }
      }
      Process { id: duP; stdout: StdioCollector { onStreamFinished: info.du = text.split("\t")[0].replace("K", " Ko").replace("M", " Mo").replace("G", " Go") } }
      onItChanged: { du = ""; if (it && !it.app) { duP.command = ["du", "-sh", "--apparent-size", it.path]; duP.running = true } }
    }
    component InfoRow: Row {
      property string k
      property string v
      spacing: 8
      Text { width: 86; text: k; font.family: w.ui; font.pixelSize: 11; color: w.ink2; horizontalAlignment: Text.AlignRight }
      Text { width: 160; text: v; font.family: w.ui; font.pixelSize: 11; color: w.ink; wrapMode: Text.WrapAnywhere }
    }

    // ---------------- Aller au dossier (⌘⇧G)
    Rectangle {
      id: goSheet
      visible: false
      z: 90
      anchors.horizontalCenter: parent.horizontalCenter; y: 60
      width: 440; height: 92; radius: 14
      color: w.dark ? Qt.rgba(0.18, 0.18, 0.19, 0.98) : Qt.rgba(0.98, 0.98, 0.99, 0.99)
      border.width: 1; border.color: w.line
      Text { x: 16; y: 12; text: T.t("Aller au dossier :"); font.family: w.ui; font.pixelSize: 13; font.weight: Font.DemiBold; color: w.ink }
      Rectangle {
        x: 16; y: 40; width: parent.width - 32; height: 30; radius: 7; color: w.glass; border.width: 1; border.color: w.accent
        TextInput {
          id: goIn
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          font.family: w.ui; font.pixelSize: 13; color: w.ink
          Keys.onReturnPressed: { var p = text.trim(); if (p.indexOf("~") === 0) p = w.home + p.slice(1); goSheet.visible = false; if (p) w.go(p); frame.forceActiveFocus() }
          Keys.onEscapePressed: { goSheet.visible = false; frame.forceActiveFocus() }
        }
      }
    }

    // ---------------- alerte
    Rectangle {
      id: askBox
      property string title
      property string sub
      property string ok
      visible: false
      z: 95
      anchors.centerIn: parent
      width: 300; height: askCol.implicitHeight + 32; radius: 16
      color: w.dark ? Qt.rgba(0.2, 0.2, 0.21, 0.99) : Qt.rgba(0.97, 0.97, 0.98, 0.99)
      border.width: 1; border.color: w.line
      Column {
        id: askCol
        x: 18; y: 16; width: parent.width - 36; spacing: 8
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "warning"; font.family: w.sym; font.pixelSize: 44; color: "#ff9f0a" }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: askBox.title; font.family: w.ui; font.pixelSize: 13; font.weight: Font.Bold; color: w.ink }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: askBox.sub; font.family: w.ui; font.pixelSize: 11; color: w.ink2 }
        Item { width: 1; height: 4 }
        Rectangle {
          width: parent.width; height: 28; radius: 8; color: "#ff453a"
          Text { anchors.centerIn: parent; text: askBox.ok; font.family: w.ui; font.pixelSize: 13; font.weight: Font.DemiBold; color: "white" }
          MouseArea { anchors.fill: parent; onClicked: { askBox.visible = false; if (w.askFn) w.askFn(); frame.forceActiveFocus() } }
        }
        Rectangle {
          width: parent.width; height: 28; radius: 8; color: w.glass
          Text { anchors.centerIn: parent; text: T.t("Annuler"); font.family: w.ui; font.pixelSize: 13; color: w.ink }
          MouseArea { anchors.fill: parent; onClicked: { askBox.visible = false; frame.forceActiveFocus() } }
        }
      }
    }

    // ---------------- menus
    Rectangle {
      id: menu
      property string kind: ""
      property var rows: []
      visible: false
      z: 100
      width: 240
      height: menuCol.implicitHeight + 10
      radius: Mac.menu.radius
      color: w.dark ? Qt.rgba(0.2, 0.2, 0.21, 0.98) : Qt.rgba(0.97, 0.97, 0.98, 0.99)
      border.width: 1; border.color: w.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
      Column {
        id: menuCol
        x: 5; y: 5; width: parent.width - 10
        Repeater {
          model: menu.rows
          Item {
            id: mr
            required property var modelData
            width: menuCol.width
            height: modelData.sep ? 11 : (modelData.tags ? 28 : 22)
            Rectangle { visible: !!mr.modelData.sep; anchors.centerIn: parent; width: parent.width - 10; height: 1; color: w.line }
            Rectangle {
              visible: !mr.modelData.sep && !mr.modelData.tags && mrMa.containsMouse && mr.modelData.enabled !== false
              anchors.fill: parent; radius: Mac.menu.selRadius; color: w.accent
            }
            Text {
              visible: !mr.modelData.sep && !mr.modelData.tags
              x: 10; anchors.verticalCenter: parent.verticalCenter
              text: (mr.modelData.check ? "✓ " : "") + (mr.modelData.label || "")
              font.family: w.ui; font.pixelSize: 13
              color: mr.modelData.enabled === false ? w.ink3 : (mrMa.containsMouse ? "white" : w.ink)
            }
            Text {
              visible: !!mr.modelData.keys
              anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
              text: mr.modelData.keys || ""; font.family: w.ui; font.pixelSize: 12
              color: mrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.8) : w.ink3
            }
            Row {
              visible: !!mr.modelData.tags
              x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 8
              Repeater {
                model: mr.modelData.tags ? w.tagDefs : []
                Rectangle {
                  required property var modelData
                  width: 16; height: 16; radius: 8; color: modelData[2]
                  MouseArea { anchors.fill: parent; onClicked: { w.toggleTag(parent.modelData[0]); w.closeMenu() } }
                }
              }
            }
            MouseArea {
              id: mrMa
              anchors.fill: parent; hoverEnabled: true
              visible: !mr.modelData.sep && !mr.modelData.tags
              onClicked: if (mr.modelData.enabled !== false && mr.modelData.fn) { w.closeMenu(); mr.modelData.fn() }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- composants
  component Capsule: Rectangle {
    default property alias content: capRow.data
    width: capRow.implicitWidth + 6; height: 32; radius: 16
    color: w.glass
    border.width: 1; border.color: w.line
    Row { id: capRow; anchors.centerIn: parent; spacing: 0 }
  }
  component Btn: Item {
    id: b
    property string glyph
    property bool active: false
    signal clicked()
    width: 34; height: 28
    opacity: enabled ? 1 : 0.35
    Rectangle { anchors.fill: parent; anchors.margins: 1; radius: 13; color: b.active ? (w.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.1)) : (bMa.containsMouse ? (w.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : "transparent") }
    Text { anchors.centerIn: parent; text: b.glyph; font.family: w.sym; font.pixelSize: 19; color: w.ink }
    MouseArea { id: bMa; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicked() }
  }
  component ColHead: Item {
    id: ch
    property string label
    property string key
    height: 26
    Text {
      x: 10; anchors.verticalCenter: parent.verticalCenter
      text: ch.label + (w.sortKey === ch.key ? (w.sortRev ? "  ˄" : "  ˅") : "")
      font.family: w.ui; font.pixelSize: 11; font.weight: w.sortKey === ch.key ? Font.DemiBold : Font.Normal; color: w.ink2
    }
    Rectangle { anchors.right: parent.right; width: 1; height: 14; anchors.verticalCenter: parent.verticalCenter; color: w.line }
    MouseArea { anchors.fill: parent; onClicked: { if (w.sortKey === ch.key) w.sortRev = !w.sortRev; else { w.sortKey = ch.key; w.sortRev = ch.key === "date" } } }
  }
  // Icône (ou vignette pour les images)
  component Thumb: Item {
    id: th
    property var it
    property int size: 64
    width: size; height: size
    IconImage {
      anchors.fill: parent
      visible: !th.it || !w.isImage(th.it) || thImg.status !== Image.Ready
      source: th.it && th.it.path !== "" ? w.iconFor(th.it) : ""
      asynchronous: true
    }
    Image {
      id: thImg
      anchors.centerIn: parent
      width: parent.width; height: parent.height
      visible: status === Image.Ready
      source: th.it && w.isImage(th.it) ? "file://" + th.it.path : ""
      sourceSize: Qt.size(th.size * 2, th.size * 2)
      fillMode: Image.PreserveAspectFit
      asynchronous: true; cache: false
    }
  }
  component RenameField: Rectangle {
    id: rf
    property var it
    readonly property bool editing: w.renaming === (it ? it.path : "-")
    visible: editing
    color: w.paper; border.width: 2; border.color: w.accent; radius: 3
    z: 5
    TextInput {
      id: rfIn
      anchors.fill: parent; anchors.margins: 3
      text: rf.it ? rf.it.name : ""
      font.family: w.ui; font.pixelSize: 12; color: w.ink; selectionColor: w.accent; selectedTextColor: "white"
      horizontalAlignment: TextInput.AlignHCenter
      clip: true
      Keys.onReturnPressed: { w.rename(rf.it, text); w.renaming = ""; frame.forceActiveFocus() }
      Keys.onEscapePressed: { w.renaming = ""; frame.forceActiveFocus() }
      onActiveFocusChanged: if (!activeFocus && rf.editing) { w.rename(rf.it, text); w.renaming = "" }
    }
    onEditingChanged: if (editing) {
      rfIn.text = it.name
      rfIn.forceActiveFocus()
      var dot = it.dir ? -1 : it.name.lastIndexOf(".")
      rfIn.select(0, dot > 0 ? dot : it.name.length)
    }
  }
  property string renaming: ""
  onItemsChanged: if (pendingRename !== "") {
    for (var i = 0; i < items.length; i++) if (items[i].path === pendingRename) { pick(i, 0); renaming = pendingRename; pendingRename = ""; break }
  }

  component Column_: Rectangle {
    id: col
    property string dir
    property int level
    width: 230; height: parent ? parent.height : 0
    color: "transparent"
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: w.line }
    FolderListModel {
      id: cfm
      folder: "file://" + col.dir
      showHidden: w.showHidden
      showDirsFirst: w.foldersFirst
      sortCaseSensitive: false
    }
    ListView {
      anchors.fill: parent; anchors.margins: 4
      model: cfm
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      delegate: Rectangle {
        id: cr
        required property string fileName
        required property string filePath
        required property bool fileIsDir
        required property var fileModified
        required property var fileSize
        readonly property var it: ({ name: fileName, path: filePath, dir: fileIsDir, size: fileIsDir ? -1 : fileSize, mtime: fileModified.getTime(), ext: fileIsDir ? "" : w.ext(fileName) })
        readonly property bool on: w.colPaths[col.level + 1] === filePath || (!!w.colPreview && w.colPreview.path === filePath)
        width: ListView.view.width; height: 22; radius: 5
        color: on ? (col.level >= w.colPaths.length - 2 ? w.accent : (w.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.1))) : "transparent"
        Thumb { x: 6; anchors.verticalCenter: parent.verticalCenter; size: 16; it: cr.it }
        Text { x: 28; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 50; elide: Text.ElideMiddle; text: w.shown(cr.it); font.family: w.ui; font.pixelSize: 13; color: cr.on && col.level === w.colPaths.length - 1 ? "white" : w.ink }
        Text { visible: cr.fileIsDir; anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: "chevron_right"; font.family: w.sym; font.pixelSize: 15; color: w.ink2 }
        MouseArea {
          anchors.fill: parent
          onClicked: { frame.forceActiveFocus(); w.colOpen(col.level, cr.it); var s = {}; s[cr.filePath] = true; w.sel = s }
          onDoubleClicked: if (!cr.fileIsDir) w.openItem(cr.it)
        }
      }
    }
  }

  function tagName(id) { for (var i = 0; i < tagDefs.length; i++) if (tagDefs[i][0] === id) return tagDefs[i][1]; return id }
  function iconGlyph(p) { return p === "/" ? "hard_drive" : (p === home ? "home" : "folder") }
  function crumbs() {
    if (place !== "") return [{ label: titleText, path: place === "trash" ? "trash" : cwd }]
    var out = [{ label: T.t("Macintosh HD"), path: "/" }], acc = ""
    cwd.split("/").forEach(function(s) { if (!s) return; acc += "/" + s; out.push({ label: w.nice(acc), path: acc }) })
    return out
  }

  // ------------------------------------------------------------- menus
  function closeMenu() { menu.visible = false }
  function menuAt(item, kind) { var p = item.mapToItem(frame, 0, item.height + 4); openMenu(kind, Math.min(p.x, frame.width - 250), p.y) }
  function menuAtPoint(item, x, y, kind) { var p = item.mapToItem(frame, x, y); openMenu(kind, Math.min(p.x, frame.width - 250), Math.min(p.y, frame.height - 300)) }
  function openMenu(kind, x, y) {
    var r = [], s = selected(), one = s.length === 1 ? s[0] : null, inTrash = place === "trash"
    if (kind === "item") {
      r.push({ label: T.t("Ouvrir"), keys: "⌘O", fn: function() { w.openSelection() } })
      if (one && !one.dir && !one.app) r.push({ label: T.t("Ouvrir avec une autre app…"), fn: function() { w.sh("xdg-open \"$(dirname \"$1\")\"", [one.path]) } })
      r.push({ sep: true })
      if (inTrash) r.push({ label: T.t("Remettre"), fn: function() { w.putBack() } })
      r.push({ label: inTrash ? T.t("Supprimer immédiatement") : T.t("Placer dans la Corbeille"), keys: "⌘⌫", fn: function() { w.trash() } })
      r.push({ sep: true })
      r.push({ label: T.t("Lire les informations"), keys: "⌘I", fn: function() { info.it = one || s[0] } })
      r.push({ label: T.t("Renommer"), keys: "↩", enabled: !!one && !one.app, fn: function() { w.renaming = one.path } })
      r.push({ label: T.t("Compresser"), enabled: place === "", fn: function() { w.compress() } })
      r.push({ label: T.t("Dupliquer"), keys: "⌘D", enabled: place === "", fn: function() { w.duplicate() } })
      r.push({ label: T.t("Créer un alias"), enabled: place === "", fn: function() { w.makeAlias() } })
      r.push({ label: T.t("Coup d'œil"), keys: "Espace", fn: function() { ql.it = one || s[0] } })
      r.push({ sep: true })
      r.push({ label: T.t("Copier"), keys: "⌘C", fn: function() { w.copy(false) } })
      r.push({ label: T.t("Copier le chemin"), keys: "⌥⌘C", fn: function() { w.copyPath() } })
      if (one && w.isImage(one)) r.push({ label: T.t("Définir comme fond d'écran"), fn: function() { w.setWallpaper(one) } })
      r.push({ sep: true })
      r.push({ tags: true })
    } else if (kind === "folder") {
      r.push({ label: T.t("Nouveau dossier"), keys: "⇧⌘N", enabled: place === "", fn: function() { w.newFolder() } })
      r.push({ label: T.t("Lire les informations"), keys: "⌘I", enabled: place === "", fn: function() { info.it = { name: w.nice(w.cwd), path: w.cwd, dir: true, size: -1, mtime: 0, ext: "" } } })
      r.push({ label: T.t("Coller l'élément"), keys: "⌘V", enabled: w.clipPaths.length > 0 && place === "", fn: function() { w.paste(false) } })
      r.push({ sep: true })
      if (inTrash) r.push({ label: T.t("Vider la Corbeille"), fn: function() { w.emptyTrash() } })
      r.push({ label: T.t("Ouvrir dans le Terminal"), fn: function() { w.openTerminal() } })
      r.push({ sep: true })
      r.push({ label: T.t("Trier par nom"), check: sortKey === "name", fn: function() { w.sortKey = "name" } })
      r.push({ label: T.t("Trier par date"), check: sortKey === "date", fn: function() { w.sortKey = "date"; w.sortRev = true } })
      r.push({ label: T.t("Trier par taille"), check: sortKey === "size", fn: function() { w.sortKey = "size"; w.sortRev = true } })
      r.push({ label: T.t("Trier par type"), check: sortKey === "kind", fn: function() { w.sortKey = "kind" } })
      r.push({ sep: true })
      r.push({ label: T.t("Afficher les options de présentation"), keys: "⌘J", fn: function() { w.menuAt(toolbar, "sort") } })
    } else if (kind === "sort") {
      r.push({ label: T.t("Nom"), check: sortKey === "name", fn: function() { w.sortKey = "name"; w.sortRev = false } })
      r.push({ label: T.t("Type"), check: sortKey === "kind", fn: function() { w.sortKey = "kind"; w.sortRev = false } })
      r.push({ label: T.t("Date de modification"), check: sortKey === "date", fn: function() { w.sortKey = "date"; w.sortRev = true } })
      r.push({ label: T.t("Taille"), check: sortKey === "size", fn: function() { w.sortKey = "size"; w.sortRev = true } })
      r.push({ sep: true })
      r.push({ label: T.t("Garder les dossiers en haut"), check: foldersFirst, fn: function() { w.foldersFirst = !w.foldersFirst } })
      r.push({ label: T.t("Afficher les fichiers cachés"), keys: "⇧⌘.", check: showHidden, fn: function() { w.showHidden = !w.showHidden } })
      r.push({ label: T.t("Afficher la barre du chemin"), keys: "⌥⌘P", check: pathBar, fn: function() { w.pathBar = !w.pathBar } })
      r.push({ label: T.t("Afficher la barre d'état"), keys: "⌘/", check: statusBar, fn: function() { w.statusBar = !w.statusBar } })
    } else if (kind === "tags") {
      r.push({ tags: true })
    } else if (kind === "more") {
      r.push({ label: T.t("Nouvelle fenêtre Finder"), keys: "⌘N", fn: function() { w.newWindowRequested(w.place === "" ? w.cwd : w.home) } })
      r.push({ label: T.t("Nouveau dossier"), keys: "⇧⌘N", enabled: place === "", fn: function() { w.newFolder() } })
      r.push({ label: T.t("Aller au dossier…"), keys: "⇧⌘G", fn: function() { w.showGo() } })
      r.push({ sep: true })
      r.push({ label: T.t("Ouvrir dans le Terminal"), fn: function() { w.openTerminal() } })
      r.push({ label: T.t("Copier le chemin"), keys: "⌥⌘C", fn: function() { w.copyPath() } })
      r.push({ label: T.t("Vider la Corbeille…"), keys: "⇧⌘⌫", fn: function() { w.emptyTrash() } })
    }
    menu.rows = r; menu.kind = kind
    menu.x = Math.max(4, x); menu.y = Math.max(4, Math.min(y, frame.height - menu.height - 4))
    menu.visible = true
  }
  function showGo() { goIn.text = place === "" ? cwd : home; goSheet.visible = true; goIn.forceActiveFocus(); goIn.selectAll() }

  // ------------------------------------------------------------- clavier
  function cols_() { return view === "icons" ? Math.max(1, Math.floor(grid.width / grid.cellWidth)) : 1 }
  function keys(ev) {
    var k = ev.key, m = ev.modifiers, cmd = (m & Qt.MetaModifier) || (m & Qt.ControlModifier), sh_ = m & Qt.ShiftModifier, alt = m & Qt.AltModifier
    if (menu.visible && k === Qt.Key_Escape) { closeMenu(); ev.accepted = true; return }
    if (askBox.visible) { if (k === Qt.Key_Escape) askBox.visible = false; else if (k === Qt.Key_Return) { askBox.visible = false; if (askFn) askFn() } ev.accepted = true; return }
    if (ql.it && (k === Qt.Key_Escape || k === Qt.Key_Space)) { ql.it = null; ev.accepted = true; return }
    if (info.it && k === Qt.Key_Escape) { info.it = null; ev.accepted = true; return }
    if (cmd) {
      if (k === Qt.Key_W) closeRequested()
      else if (k === Qt.Key_N && sh_) newFolder()
      else if (k === Qt.Key_N) newWindowRequested(place === "" ? cwd : home)
      else if (k === Qt.Key_Up) up()
      else if (k === Qt.Key_Down || k === Qt.Key_O) openSelection()
      else if (k === Qt.Key_BracketLeft) goBack()
      else if (k === Qt.Key_BracketRight) goFwd()
      else if (k === Qt.Key_Backspace && sh_) emptyTrash()
      else if (k === Qt.Key_Backspace) trash()
      else if (k === Qt.Key_I) info.it = selected()[0] || null
      else if (k === Qt.Key_D && sh_) go(home + "/Desktop")
      else if (k === Qt.Key_D) duplicate()
      else if (k === Qt.Key_A && sh_) go("apps")
      else if (k === Qt.Key_A) selectAll()
      else if (k === Qt.Key_C && alt) copyPath()
      else if (k === Qt.Key_C) copy(false)
      else if (k === Qt.Key_X) copy(true)
      else if (k === Qt.Key_V) paste(alt)
      else if (k === Qt.Key_F) searchIn.forceActiveFocus()
      else if (k === Qt.Key_G && sh_) showGo()
      else if (k === Qt.Key_H && sh_) go(home)
      else if (k === Qt.Key_O && sh_) go(home + "/Documents")
      else if (k === Qt.Key_L && alt) go(home + "/Downloads")
      else if (k === Qt.Key_F && sh_) go("recents")
      else if (k === Qt.Key_Period && sh_) showHidden = !showHidden
      else if (k === Qt.Key_P && alt) pathBar = !pathBar
      else if (k === Qt.Key_Slash) statusBar = !statusBar
      else if (k === Qt.Key_1) view = "icons"
      else if (k === Qt.Key_2) view = "list"
      else if (k === Qt.Key_3) view = "columns"
      else if (k === Qt.Key_4) view = "gallery"
      else if (k === Qt.Key_Plus || k === Qt.Key_Equal) iconSize = Math.min(128, iconSize + 16)
      else if (k === Qt.Key_Minus) iconSize = Math.max(32, iconSize - 16)
      else return
      ev.accepted = true; return
    }
    var n = items.length, c = cols_()
    if (k === Qt.Key_Space) { var s = selected(); ql.it = s.length ? s[0] : (cur >= 0 ? items[cur] : null) }
    else if (k === Qt.Key_Return || k === Qt.Key_Enter) { var t = selected(); if (t.length === 1 && !t[0].app) renaming = t[0].path }
    else if (k === Qt.Key_Right) pick(Math.min(n - 1, cur + (view === "icons" || view === "gallery" ? 1 : 0)), m)
    else if (k === Qt.Key_Left) pick(Math.max(0, cur - (view === "icons" || view === "gallery" ? 1 : 0)), m)
    else if (k === Qt.Key_Down) pick(Math.min(n - 1, cur < 0 ? 0 : cur + (view === "icons" ? c : 1)), m)
    else if (k === Qt.Key_Up) pick(Math.max(0, cur - (view === "icons" ? c : 1)), m)
    else if (k === Qt.Key_Escape) clearSel()
    else if (ev.text && ev.text.length === 1 && ev.text > " ") {
      // Taper les premières lettres sélectionne l'élément.
      typed = (typeT.running ? typed : "") + ev.text.toLowerCase(); typeT.restart()
      for (var i = 0; i < n; i++) if (items[i].name.toLowerCase().indexOf(typed) === 0) { pick(i, 0); break }
    }
    else return
    ev.accepted = true
    if (ql.it && cur >= 0) ql.it = items[cur]
  }
  property string typed: ""
  Timer { id: typeT; interval: 900 }
  onCurChanged: {
    if (cur < 0) return
    if (view === "icons") grid.positionViewAtIndex(cur, GridView.Contain)
    else if (view === "list") list.positionViewAtIndex(cur, ListView.Contain)
  }
  onViewChanged: { if (view === "columns") { colPaths = place === "" ? [cwd] : []; colPreview = null } frame.forceActiveFocus() }
}
