import QtQuick
import "Mac.js" as Mac
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T.js" as T

// Liquid Glass — menus de la barre façon macOS : nom de l'app active (gras),
// Fichier, Édition, Présentation, Fenêtre, Aide. Les commandes sont envoyées à
// l'app active (liquid-glass key …) ou agissent sur sa fenêtre (liquid-glass
// window …). Un menu ouvert, survoler un autre titre l'ouvre (comme sur Mac) ;
// ← → passent d'un menu à l'autre, ↑ ↓ Entrée naviguent.
Panel {
  id: root
  moduleName: "liquid-glass.menubar"
  ipcTarget: "liquid-glass.menubar"

  readonly property string uiFont: "Inter"
  readonly property color tint: root.bar ? root.bar.barForeground : Commons.Color.foreground

  // ---- app active
  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: toplevel ? (toplevel.appId || "") : ""
  readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
  // Le Finder Liquid Glass (apps/finder) est une fenêtre Quickshell.
  readonly property bool isFinder: !toplevel || (appId === "org.quickshell" && String(toplevel.title || "").indexOf("Finder") === 0)
  readonly property string appName: {
    if (!toplevel) return "Finder"
    if (isFinder) return "Finder"
    if (entry && entry.name) return entry.name
    if (appId === "") return toplevel.title || "Finder"
    var last = appId.split(".").pop()
    return last.charAt(0).toUpperCase() + last.slice(1)
  }

  function lg(args) { return ["liquid-glass"].concat(args) }
  function sh(id, verb) { return ["omarchy-shell", "shell", verb || "toggle", id] }

  // [titre, [[libellé, commande (argv) | null = grisé, raccourci], "" = séparateur]]
  function finder(p) { return ["liquid-glass", "finder", "--go", p] }
  // Menu « Aller » du Finder (navigue dans la fenêtre du Finder au premier plan).
  readonly property var goMenu: [T.t("Aller"), [
    [T.t("Récents"), finder("recents"), "⇧⌘F"],
    ["Documents", finder("~/Documents"), "⇧⌘O"],
    [T.t("Bureau"), finder("~/Desktop"), "⇧⌘D"],
    [T.t("Téléchargements"), finder("~/Downloads"), "⌥⌘L"],
    [T.t("Départ"), finder("~"), "⇧⌘H"],
    [T.t("Ordinateur"), finder("/"), "⇧⌘C"],
    ["Applications", finder("apps"), "⇧⌘A"],
    [T.t("Utilitaires"), finder("/usr/bin"), "⇧⌘U"],
    "",
    [T.t("Aller au dossier…"), finder("goto"), "⇧⌘G"]
  ]]
  readonly property var menus: isFinder ? baseMenus.slice(0, 3).concat([goMenu]).concat(baseMenus.slice(3)) : baseMenus
  readonly property var baseMenus: [
    [appName, [
      [T.t("Réglages…"), lg(["window", "settings"]), "⌘,"],
      "",
      [T.t("Masquer ") + appName, lg(["window", "hide"]), "⌘H"],
      [T.t("Masquer les autres"), lg(["window", "hide-others"]), "⌥⌘H"],
      [T.t("Tout afficher"), lg(["window", "show-all"]), ""],
      "",
      [T.t("Quitter ") + appName, lg(["window", "quit"]), "⌘Q"]
    ]],
    [T.t("Fichier"), [
      root.isFinder ? [T.t("Nouvelle fenêtre Finder"), lg(["finder", "--new"]), "⌘N"] : [T.t("Nouvelle fenêtre"), lg(["key", "new"]), "⌘N"],
      [T.t("Ouvrir…"), lg(["key", "open"]), "⌘O"],
      "",
      [T.t("Fermer la fenêtre"), ["hyprctl", "dispatch", "hl.dsp.window.close()"], "⌘W"],
      [T.t("Enregistrer"), lg(["key", "save"]), "⌘S"],
      [T.t("Enregistrer sous…"), lg(["key", "saveas"]), "⇧⌘S"],
      "",
      [T.t("Imprimer…"), lg(["key", "print"]), "⌘P"]
    ]],
    [T.t("Édition"), [
      [T.t("Annuler"), lg(["key", "undo"]), "⌘Z"],
      [T.t("Rétablir"), lg(["key", "redo"]), "⇧⌘Z"],
      "",
      [T.t("Couper"), lg(["key", "cut"]), "⌘X"],
      [T.t("Copier"), lg(["key", "copy"]), "⌘C"],
      [T.t("Coller"), lg(["key", "paste"]), "⌘V"],
      [T.t("Tout sélectionner"), lg(["key", "selectall"]), "⌘A"],
      "",
      [T.t("Rechercher…"), lg(["key", "find"]), "⌘F"],
      "",
      [T.t("Presse-papiers…"), ["omarchy-shell", "shell", "summon", "liquid-glass.spotlight", "{\"mode\":\"clipboard\"}"], ""],
      [T.t("Émojis et symboles"), sh("omarchy.emojis"), "🌐E"]
    ]],
    [T.t("Présentation"), (root.isFinder ? [
      [T.t("Par icônes"), lg(["finder", "--view", "icons"]), "⌘1"],
      [T.t("Par liste"), lg(["finder", "--view", "list"]), "⌘2"],
      [T.t("Par colonnes"), lg(["finder", "--view", "columns"]), "⌘3"],
      [T.t("Par galerie"), lg(["finder", "--view", "gallery"]), "⌘4"],
      ""
    ] : []).concat([
      [T.t("Zoom avant"), lg(["key", "zoomin"]), "⌘+"],
      [T.t("Zoom arrière"), lg(["key", "zoomout"]), "⌘−"],
      [T.t("Taille réelle"), lg(["key", "zoomreset"]), "⌘0"],
      "",
      ["Mission Control", sh("liquid-glass.mission"), "⌘↑"],
      [T.t("Afficher le bureau"), lg(["show-desktop"]), "⌘F3"],
      "",
      [T.t("Passer en plein écran"), lg(["window", "fullscreen"]), "⌃⌘F"]
    ])],
    [T.t("Fenêtre"), [
      [T.t("Réduire"), lg(["window", "minimize"]), "⌘M"],
      ["Zoom", lg(["window", "zoom"]), ""],
      [T.t("Remplir"), lg(["window", "fill"]), "⌃⌥F"],
      [T.t("Centrer"), lg(["window", "center"]), "⌃⌥C"],
      "",
      [T.t("Placer à gauche de l'écran"), lg(["window", "left"]), "⌃⌥←"],
      [T.t("Placer à droite de l'écran"), lg(["window", "right"]), "⌃⌥→"],
      [T.t("Placer en haut de l'écran"), lg(["window", "top"]), "⌃⌥↑"],
      [T.t("Placer en bas de l'écran"), lg(["window", "bottom"]), "⌃⌥↓"],
      "",
      [T.t("Flottante / mosaïque"), lg(["window", "float"]), "⌘T"],
      [T.t("Toujours au premier plan"), lg(["window", "pin"]), ""],
      "",
      [T.t("Déplacer vers le bureau suivant"), lg(["window", "next-desktop"]), ""],
      [T.t("Déplacer vers le bureau précédent"), lg(["window", "prev-desktop"]), ""],
      "",
      [T.t("Tout ramener au premier plan"), lg(["window", "show-all"]), ""]
    ]],
    [T.t("Aide"), [
      [T.t("Raccourcis clavier Liquid Glass"), sh("liquid-glass.cheatsheet"), "⌘K"],
      [T.t("Tous les raccourcis Omarchy"), ["omarchy-menu-keybindings"], "⌘⇧K"],
      "",
      [T.t("Réglages Système…"), ["omarchy-shell", "liquid-glass.settings", "toggle"], ""],
      [T.t("Manuel d'Omarchy"), ["xdg-open", "https://learn.omacom.io/2/the-omarchy-manual"], ""]
    ]]
  ]

  property int current: 0      // menu ouvert
  property int cursor: -1      // ligne surlignée
  readonly property var items: menus[current] ? menus[current][1] : []

  function openMenu(i) {
    if (i < 0 || i >= menus.length) return
    current = i
    cursor = -1
    if (!root.opened) root.open()
  }
  function step(delta) {
    var n = items.length
    if (!n) return
    var i = cursor
    for (var k = 0; k < n; k++) {
      i = (i + delta + n) % n
      if (items[i] !== "" && items[i][1]) { cursor = i; return }
    }
  }
  function activate(i) {
    var e = items[i]
    if (!e || e === "" || !e[1]) return
    root.close()
    Util.execArgv(e[1])
  }

  // La marque « panneau ouvert » de la barre Omarchy se place sous le titre du
  // menu ouvert (et non sous toute la rangée de menus).
  readonly property Item openPanelIndicatorItem: titleRep.count > current ? titleRep.itemAt(current) : null

  implicitWidth: titles.implicitWidth
  implicitHeight: root.bar ? root.bar.barSize : Style.space(Mac.menuBar.height)
  visible: !(root.bar && root.bar.vertical)

  Row {
    id: titles
    height: parent.height
    Repeater {
      id: titleRep
      model: root.menus
      delegate: Item {
        id: t
        required property var modelData
        required property int index
        readonly property bool active: root.opened && root.current === index
        width: label.implicitWidth + Style.space(Mac.menuBar.titlePad * 2 - 2)
        height: titles.height
        Rectangle {
          anchors.centerIn: parent
          width: parent.width; height: Style.space(Mac.menuBar.highlightH)
          radius: Style.space(Mac.menuBar.highlightRadius + 1)
          color: root.tint
          opacity: t.active ? 0.14 : (tMouse.containsMouse ? 0.07 : 0)
          Behavior on opacity { NumberAnimation { duration: Style.duration(90) } }
        }
        Text {
          id: label
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: t.index === 0 ? String(t.modelData[0]).slice(0, 40) : t.modelData[0]
          font.family: root.uiFont
          font.pixelSize: Style.space(Mac.font.body)
          font.weight: t.index === 0 ? Font.Bold : Font.Normal
          font.letterSpacing: Mac.tracking(Mac.font.body)
          color: root.tint
        }
        MouseArea {
          id: tMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: { if (root.opened && root.current === t.index) root.close(); else root.openMenu(t.index) }
          // Menu déjà ouvert : survoler un autre titre l'ouvre directement.
          onContainsMouseChanged: if (containsMouse && root.opened && root.current !== t.index) root.openMenu(t.index)
        }
      }
    }
  }

  // Point d'ancrage invisible : le panneau d'Omarchy se centre sur son ancre ;
  // on la décale pour que le menu tombe aligné à gauche sous son titre, comme sur Mac.
  Item {
    id: menuAnchor
    readonly property Item title: titleRep.count > root.current ? titleRep.itemAt(root.current) : null
    x: (title ? title.x : 0) - panel.padding + panel.contentWidth / 2 - width / 2
    y: 0
    width: 1; height: parent.height
  }

  KeyboardPanel {
    id: panel
    anchorItem: menuAnchor
    owner: root
    bar: root.bar
    open: root.opened
    gap: Style.space(3)
    padding: Style.space(Mac.menu.padV)
    focusTarget: panel.loadedContent
    contentWidth: Style.space(Math.max(Mac.menu.minWidth + 40, root.current === 4 ? 270 : 230))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: list.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(d) { root.openMenu((root.current + d + root.menus.length) % root.menus.length) }
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.step(dy)
        else if (dx !== 0) root.openMenu((root.current + dx + root.menus.length) % root.menus.length)
      }
      onActivateRequested: root.activate(root.cursor)

      Column {
        id: list
        width: parent.width
        Repeater {
          model: root.items
          delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool separator: modelData === ""
            readonly property bool enabled: !separator && !!modelData[1]
            readonly property bool hot: enabled && (rowMouse.containsMouse || root.cursor === index)
            width: list.width
            height: separator ? Style.space(Mac.menu.separatorMargin * 2 + 1) : Style.space(Mac.menu.row)

            Rectangle {
              visible: row.separator
              anchors.verticalCenter: parent.verticalCenter
              x: Style.space(Mac.menu.inset + 4); width: parent.width - x * 2; height: 1
              color: Commons.Color.popups.text; opacity: 0.12
            }
            Rectangle {
              visible: !row.separator
              anchors.fill: parent
              radius: Style.space(Mac.menu.selRadius)
              color: Commons.Color.accent
              opacity: row.hot ? 0.92 : 0
            }
            Text {
              visible: !row.separator
              anchors.verticalCenter: parent.verticalCenter
              x: Style.space(10)
              width: parent.width - x - shortcut.implicitWidth - Style.space(22)
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: row.separator ? "" : row.modelData[0]
              font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.body)
              color: row.hot ? "#ffffff" : Commons.Color.popups.text
              opacity: row.enabled ? 1 : Mac.label.tertiary
            }
            Text {
              id: shortcut
              visible: !row.separator && row.modelData[2] !== ""
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right; anchors.rightMargin: Style.space(10)
              textFormat: Text.PlainText
              text: row.separator ? "" : row.modelData[2]
              font.family: root.uiFont; font.pixelSize: Style.space(Mac.font.body)
              color: row.hot ? "#ffffff" : Commons.Color.popups.text
              opacity: row.hot ? 0.9 : Mac.label.secondary
            }
            MouseArea {
              id: rowMouse
              anchors.fill: parent
              enabled: row.enabled
              hoverEnabled: true
              onEntered: root.cursor = row.index
              onClicked: root.activate(row.index)
            }
          }
        }
      }
    }
  }
}
