import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "T.js" as T

// ⌘K du bureau Linux : tous les raccourcis, lus en direct dans Hyprland
// (`hyprctl binds -j`), à la place de la liste d'Omarchy. Groupés (Ce bureau,
// Fenêtres, Espaces, Applications, Médias, Menus…), traduits, les séries
// « espace 1…10 » réunies en une ligne. Taper pour filtrer, Échap pour fermer.
// Allure du style : police, arrondis, couleurs (Windows : carte Fluent, Mono :
// noir et gris, Jouet : contours épais…).
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-keys"
  WlrLayershell.keyboardFocus: s.kbd(true)

  readonly property string st: s.style
  readonly property bool toy: st === "jouet"
  readonly property bool monoStyle: st === "mono"
  // Jouet : police pixel seulement pour le titre (illisible en petit : « Ctrl » → « Otrl »).
  readonly property string font: ["blanc", "sombre", "foret"].indexOf(st) >= 0 ? "JetBrainsMono Nerd Font" : (toy ? "Rubik" : s.sansFont)
  readonly property string titleFont: toy ? s.sansFont : font
  readonly property color panelBg: monoStyle ? s.monoFrame : (toy ? s.surfaceMid : s.alpha(s.surfaceMid, 0.97))
  readonly property color ink: s.colOnSurface
  readonly property color sub: monoStyle ? s.colOnSurfaceVariant : (toy ? s.colOnSurfaceVariant : s.colOnSurfaceVariant)
  readonly property color acc: monoStyle ? s.primary : s.primary
  readonly property int rad: monoStyle ? 22 : (toy ? 20 : Math.max(6, s.radius))

  property string query: ""
  property var binds: []
  property bool revealed: false
  Component.onCompleted: { revealed = true; proc.running = true; input.forceActiveFocus() }

  Process {
    id: proc
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector { onStreamFinished: { try { win.binds = JSON.parse(text) } catch (e) { win.binds = [] } } }
  }

  // ------------------------------------------------------------ données
  readonly property var mods: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Maj"], [128, "AltGr"]]
  readonly property var keyNames: ({
    "SPACE": "Espace", "space": "Espace", "RETURN": "Entrée", "Return": "Entrée", "ESCAPE": "Échap", "Escape": "Échap",
    "TAB": "Tab", "Tab": "Tab", "DELETE": "Suppr", "Delete": "Suppr", "BACKSPACE": "⌫", "LEFT": "←", "RIGHT": "→",
    "UP": "↑", "DOWN": "↓", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "grave": "§", "SLASH": "/", "COMMA": ",",
    "PERIOD": ".", "MINUS": "-", "EQUAL": "=", "Print": "Impr", "PRINT": "Impr", "Home": "Début", "End": "Fin",
    "mouse:272": "Clic", "mouse:273": "Clic droit", "mouse_down": "Molette ↓", "mouse_up": "Molette ↑",
    "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Muet", "XF86AudioMicMute": "Micro",
    "XF86MonBrightnessUp": "Lum +", "XF86MonBrightnessDown": "Lum −", "XF86AudioPlay": "⏯", "XF86AudioPause": "⏸",
    "XF86AudioNext": "⏭", "XF86AudioPrev": "⏮", "XF86PowerOff": "⏻", "XF86KbdBrightnessUp": "Clavier +",
    "XF86KbdBrightnessDown": "Clavier −", "XF86KbdLightOnOff": "Rétroéclairage", "XF86TouchpadToggle": "Pavé",
    "XF86Calculator": "Calc", "XF86Eject": "⏏", "code:201": "Copilot"
  })
  // Traduction des descriptions d'Omarchy (anglais) les plus courantes.
  readonly property var tr: [
    [/^Switch to workspace/, "Aller à l'espace"], [/^Move window silently to workspace/, "Envoyer la fenêtre (sans suivre) à l'espace"],
    [/^Move window to workspace/, "Envoyer la fenêtre à l'espace"], [/^Close window$/, "Fermer la fenêtre"],
    [/^Close all windows$/, "Fermer toutes les fenêtres"], [/^Full screen$/, "Plein écran"], [/^Toggle window floating\/tiling$/, "Flottante / en mosaïque"],
    [/^Volume up$/, "Monter le son"], [/^Volume down$/, "Baisser le son"], [/^Mute$/, "Couper le son"], [/^Brightness up$/, "Plus lumineux"],
    [/^Brightness down$/, "Moins lumineux"], [/^Next track$/, "Morceau suivant"], [/^Previous track$/, "Morceau précédent"],
    [/^Play$/, "Lecture"], [/^Pause$/, "Pause"], [/^Universal copy$/, "Copier"], [/^Universal paste$/, "Coller"], [/^Universal cut$/, "Couper"],
    [/^Select all$/, "Tout sélectionner"], [/^Clipboard manager$/, "Presse-papiers"], [/^Emojis$/, "Émojis"],
    [/^Terminal$/, "Terminal"], [/^Browser$/, "Navigateur"], [/^File manager$/, "Fichiers"], [/^Music$/, "Musique"],
    [/^Toggle scratchpad$/, "Bloc-notes flottant"], [/^Focus on next window$/, "Fenêtre suivante"], [/^Focus on previous window$/, "Fenêtre précédente"],
    [/^Former workspace$/, "Espace précédent"], [/^Swap window to the left$/, "Échanger à gauche"], [/^Swap window to the right$/, "Échanger à droite"],
    [/^Swap window up$/, "Échanger en haut"], [/^Swap window down$/, "Échanger en bas"], [/^Toggle window split$/, "Changer la découpe"],
    [/^Toggle window grouping$/, "Grouper les fenêtres"], [/^Move window$/, "Déplacer la fenêtre"], [/^Resize window$/, "Redimensionner la fenêtre"],
    [/^Lock system$/, "Verrouiller"], [/^Screenshot$/, "Capture d'écran"], [/^Color picker$/, "Pipette"], [/^Switch input language$/, "Changer de clavier"],
    [/^Pop window out \(float & pin\)$/, "Détacher la fenêtre (flottante, épinglée)"], [/^Agent$/, "Agent IA (Claude…)"],
    [/^Move window to (\w+) monitor$/, "Fenêtre vers l'écran $1"], [/^Move workspace to (\w+) monitor$/, "Espace vers l'écran $1"],
    [/^Cycle workspace layout back$/, "Disposition précédente"], [/^Cycle workspace layout$/, "Disposition suivante"],
    [/^Scroll active workspace forward$/, "Espace suivant (molette)"], [/^Scroll active workspace backward$/, "Espace précédent (molette)"],
    [/^Previous workspace$/, "Espace précédent"], [/^Next workspace$/, "Espace suivant"], [/^Save window width$/, "Mémoriser la largeur"],
    [/^Restore window width$/, "Rétablir la largeur"], [/^Pseudo window$/, "Pseudo-mosaïque"], [/^Move window to scratchpad$/, "Envoyer au bloc-notes flottant"],
    [/^Toggle Quake console$/, "Console déroulante"], [/^Move window to Quake console$/, "Envoyer à la console déroulante"],
    [/^Minimize window to the dock$/, "Réduire dans le Dock"], [/^Expand window (\w+)( a little| a lot)?$/, "Agrandir vers $1$2"],
    [/^Shrink window (\w+)( a little| a lot)?$/, "Rétrécir vers $1$2"], [/^Tiled full screen$/, "Plein écran en mosaïque"],
    [/^Full width$/, "Pleine largeur"], [/^Move active window out of group$/, "Sortir du groupe"], [/^Next window in group$/, "Fenêtre suivante du groupe"],
    [/^Previous window in group$/, "Fenêtre précédente du groupe"], [/^Switch to group window$/, "Fenêtre du groupe"],
    [/^Focus on next monitor$/, "Écran suivant"], [/^Focus on previous monitor$/, "Écran précédent"], [/^Reveal active window on top$/, "Fenêtre active au premier plan"],
    [/^Mute microphone$/, "Couper le micro"], [/^Switch audio output$/, "Changer de sortie audio"], [/^Keyboard brightness (up|down)$/, "Rétroéclairage $1"],
    [/^Brightness (maximum|minimum)$/, "Luminosité $1"], [/^Volume (up|down) precise$/, "Son $1 (fin)"], [/^Capture menu$/, "Menu capture"],
    [/^Toggle menu$/, "Menu bascules"], [/^Hardware menu$/, "Menu matériel"], [/^System menu$/, "Menu système"], [/^Background switcher$/, "Fonds d'écran"],
    [/^Monitor scaling (up|down)$/, "Échelle de l'écran $1"], [/^Switch input language back$/, "Clavier précédent"], [/^Move window to group on (\w+)$/, "Vers le groupe $1"],
    [/^Move grouped window focus (\w+)$/, "Focus du groupe $1"]
  ]
  readonly property var words: ({ "left": "gauche", "right": "droite", "up": "haut", "down": "bas", "top": "haut", "bottom": "bas",
                                  " a little": " un peu", " a lot": " beaucoup", "maximum": "maximale", "minimum": "minimale" })
  function french(d) {
    for (var i = 0; i < tr.length; i++) {
      var m = tr[i][0].exec(d)
      if (!m) continue
      var out = tr[i][1]
      for (var j = 1; j < m.length; j++) { var w = m[j] || ""; out = out.replace("$" + j, words[w] !== undefined ? words[w] : w) }
      return out
    }
    return d
  }
  function combo(b) {
    var out = []
    for (var i = 0; i < mods.length; i++) if (b.modmask & mods[i][0]) out.push(mods[i][1])
    var k = String(b.key || "")
    var m = /(\d+)$/.exec(b.description || "")
    if (k === "" && m) k = String(Number(m[1]) % 10)
    else if (k === "") k = "…"
    out.push(keyNames[k] !== undefined ? keyNames[k] : (k.length === 1 ? k.toUpperCase() : k))
    return out
  }
  function group(d) {
    if (/[éèàçêô]|Bureau|Lanceur|Réglages|Teinte|Fonds|Rice|Alimentation|Capture d'écran|Claude/.test(d)) return 0
    if (/workspace|espace/i.test(d)) return 2
    if (/window|group|scratchpad|Quake|focus|monitor|fenêtre|screen|width|Pseudo/i.test(d)) return 1
    if (/Volume|Brightness|track|Mute|media|backlight|touchpad|Play|Pause|Eject|audio|microphone/i.test(d)) return 4
    if (/menu|Emoji|Clipboard|keybindings|Background|Screenshot|screenrecord|record|picker|Lock|language|copy|paste|cut|Select all|Notification|Night|idle|Toggle/i.test(d)) return 5
    // Appli : un ou deux mots en capitale sans verbe (« Terminal », « Obsidian », « Google Messages »).
    if (/^[A-Z0-9][\w.+-]*( [A-Z0-9][\w.+-]*)?$/.test(d) && !/^(Share|Transcode|Show|Set|Clear|Make|Toggle)\b/.test(d)) return 3
    return 5
  }
  readonly property var groupNames: ["Ce bureau", "Fenêtres", "Espaces", "Applications", "Son, lumière, médias", "Menus et outils"]
  readonly property var groupIcons: ["auto_awesome", "select_window", "view_carousel", "apps", "graphic_eq", "construction"]
  // Groupes → lignes { label, keys: [[combo…]…] }, séries « …1 … …10 » réunies.
  readonly property var model: {
    var q = query.trim().toLowerCase()
    var groups = [[], [], [], [], [], []], seen = {}
    for (var i = 0; i < binds.length; i++) {
      var b = binds[i]
      if (!b.description) continue
      if (b.submap && b.submap !== "") continue
      var d = String(b.description)
      var label = french(d.replace(/\s*\d+$/, ""))
      var series = /\d+$/.test(d)
      var c = combo(b)
      var key = label + "|" + c.slice(0, -1).join("+")
      var hay = (label + " " + c.join(" ")).toLowerCase()
      if (q !== "" && hay.indexOf(q) < 0) continue
      if (seen[key] !== undefined && series) {
        var row = seen[key]
        row.last = c[c.length - 1]
        continue
      }
      var g = group(d)
      var r = { label: label + (series ? "" : ""), keys: c, last: "", series: series }
      if (series) seen[key] = r
      else if (seen[label + "#"] !== undefined) { seen[label + "#"].alt.push(c); continue }
      else { r.alt = []; seen[label + "#"] = r }
      groups[g].push(r)
    }
    var out = []
    for (var k = 0; k < groups.length; k++) if (groups[k].length) out.push({ name: groupNames[k], icon: groupIcons[k], rows: groups[k], index: k })
    return out
  }
  // Colonnes équilibrées (maçonnerie) : chaque groupe va dans la colonne la plus courte.
  readonly property int colCount: box.width > 1000 ? 3 : 2
  readonly property var columns: {
    var cols = [], h = []
    for (var c = 0; c < colCount; c++) { cols.push([]); h.push(0) }
    for (var i = 0; i < model.length; i++) {
      var best = 0
      for (var j = 1; j < colCount; j++) if (h[j] < h[best]) best = j
      cols[best].push(model[i])
      h[best] += model[i].rows.length * 26 + 50
    }
    return cols
  }

  // ------------------------------------------------------------ vue
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, s.darkSkin || monoStyle ? 0.55 : 0.3)
    opacity: win.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200 } }
    MouseArea { anchors.fill: parent; onClicked: s.closeAll() }
  }

  Item {
    id: box
    width: Math.min(win.width - 80, 1180)
    height: Math.min(win.height - 90, 760)
    anchors.centerIn: parent
    anchors.verticalCenterOffset: win.revealed ? 0 : 30
    opacity: win.revealed ? 1 : 0
    scale: win.revealed ? 1 : 0.97
    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 460; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }

    Rectangle { visible: toy || st === "blanc"; x: 8; y: 8; width: parent.width; height: parent.height; radius: win.rad; color: toy ? "#1b1030" : s.colOnSurface }
    RectangularShadow { visible: !toy; anchors.fill: body; radius: win.rad; blur: 40; offset.y: 14; color: Qt.rgba(0, 0, 0, 0.35) }
    Rectangle {
      id: body
      anchors.fill: parent
      radius: win.rad
      color: win.panelBg
      border.width: toy ? 3 : 1
      border.color: toy ? "#1b1030" : s.alpha(win.ink, 0.1)
      MouseArea { anchors.fill: parent }
    }

    // En-tête : titre, style, recherche
    Row {
      id: head
      x: 28; y: 22
      spacing: 14
      Rectangle {
        width: 42; height: 42; radius: toy ? 12 : 21
        color: s.alpha(win.acc, monoStyle ? 0.15 : 0.18)
        border.width: toy ? 2 : 0; border.color: "#1b1030"
        MIcon { anchors.centerIn: parent; icon: "keyboard"; size: 24; fill: 1; color: win.acc }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        Text { text: T.t("Raccourcis"); font.family: win.titleFont; font.pixelSize: 24; font.weight: Font.Bold; color: win.ink }
        Text { text: T.t("Bureau ") + (s.style === "gouts" ? T.t("Mes goûts") : s.style.charAt(0).toUpperCase() + s.style.slice(1)) + T.t(" · lus en direct dans Hyprland"); font.family: win.font; font.pixelSize: 12; color: win.sub }
      }
    }
    Rectangle {
      id: field
      anchors.right: parent.right; anchors.rightMargin: 28
      y: 24; width: 320; height: 40
      radius: toy ? 14 : (monoStyle ? 20 : Math.min(20, win.rad))
      color: monoStyle ? s.surfaceMid : s.alpha(win.ink, 0.07)
      border.width: toy ? 2.5 : 0; border.color: "#1b1030"
      MIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 19; color: win.sub }
      TextInput {
        id: input
        x: 40; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52
        font.family: win.font; font.pixelSize: 14; color: win.ink; clip: true
        selectionColor: win.acc
        onTextChanged: win.query = text
        Text { visible: parent.text === ""; text: T.t("Filtrer (ex. capture, fenêtre, son)"); font: parent.font; color: win.sub }
        Keys.onEscapePressed: { if (text !== "") text = ""; else s.closeAll() }
        Keys.onDownPressed: flick.contentY = Math.min(flick.contentHeight - flick.height, flick.contentY + 120)
        Keys.onUpPressed: flick.contentY = Math.max(0, flick.contentY - 120)
      }
    }

    Flickable {
      id: flick
      x: 22; y: 86
      width: parent.width - 44; height: parent.height - 100
      contentHeight: flow.height + 10
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Behavior on contentY { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
      Row {
        id: flow
        width: parent.width
        spacing: 12
        Repeater {
          model: win.columns
          delegate: Column {
            id: colm
            required property var modelData
            width: (flow.width - (win.colCount - 1) * 12) / win.colCount
            spacing: 12
            Repeater {
              model: colm.modelData
              delegate: Rectangle {
                id: card
                required property var modelData
                width: colm.width
                height: cardCol.implicitHeight + 24
                radius: Math.max(6, win.rad - 6)
                color: monoStyle ? s.surfaceLow : (toy ? s.alpha(s.rainbow[modelData.index % 6], 0.16) : s.alpha(win.ink, 0.04))
                border.width: toy ? 2 : (st === "blanc" || st === "sombre" ? 1 : 0)
                border.color: toy ? "#1b1030" : s.alpha(win.ink, 0.15)
                opacity: win.revealed ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: card.modelData.index * 45 } NumberAnimation { duration: 220 } } }
                Column {
                  id: cardCol
                  x: 14; y: 12
                  width: parent.width - 28
                  spacing: 4
                  Row {
                    spacing: 8
                    bottomPadding: 4
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: card.modelData.icon; size: 18; fill: 1; color: win.acc }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: card.modelData.name; font.family: win.font; font.pixelSize: 14; font.weight: Font.Bold; color: win.ink }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: card.modelData.rows.length; font.family: win.font; font.pixelSize: 11; color: win.sub }
                  }
                  Repeater {
                    model: card.modelData.rows
                    delegate: KeyRow { width: cardCol.width }
                  }
                }
              }
            }
          }
        }
      }
    }
    Text {
      visible: win.model.length === 0
      anchors.centerIn: parent
      text: win.binds.length ? T.t("Aucun raccourci pour « ") + win.query + " »" : T.t("Lecture des raccourcis…")
      font.family: win.font; font.pixelSize: 14; color: win.sub
    }
  }

  component KeyRow: Item {
    id: row
    required property var modelData
                      height: 26
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - caps.width - 10
      elide: Text.ElideRight
      text: row.modelData.label
      font.family: win.font; font.pixelSize: 12; color: win.ink
    }
    Row {
      id: caps
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Repeater {
        model: row.modelData.series && row.modelData.last !== ""
               ? row.modelData.keys.slice(0, -1).concat([row.modelData.keys[row.modelData.keys.length - 1] + "…" + row.modelData.last])
               : row.modelData.keys
        delegate: Rectangle {
          required property string modelData
          height: 20
          width: Math.max(20, capText.implicitWidth + 12)
          radius: toy ? 6 : (monoStyle ? 10 : Math.min(6, win.rad / 2))
          color: modelData === "Super" ? s.alpha(win.acc, 0.22) : (monoStyle ? s.surfaceHigh : s.alpha(win.ink, 0.08))
          border.width: toy ? 1.5 : 1
          border.color: toy ? "#1b1030" : s.alpha(win.ink, 0.14)
          Text {
            id: capText
            anchors.centerIn: parent
            text: parent.modelData
            font.family: win.font; font.pixelSize: 10; font.weight: Font.DemiBold
            color: win.ink
          }
        }
      }
    }
  }
}
