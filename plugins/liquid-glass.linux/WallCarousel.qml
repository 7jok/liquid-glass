import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Carrousel de fonds façon Serpantinum : cartes en parallélogramme, la carte du
// centre large, les voisines en lamelles qui rapetissent. Puces de catégorie
// (lain, anime, abstrait, ASCII, minimal, fruits, générés), ←/→ ou molette pour
// défiler (ressort), Entrée ou clic sur la carte du centre pour l'appliquer,
// Échap pour fermer. ⌃⌘Espace / `omarchy-shell liquid-glass.linux wallpapers`.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-walls"
  WlrLayershell.keyboardFocus: s.testing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

  readonly property string home: Quickshell.env("HOME")
  readonly property var cats: [["all", T.t("Tout")], ["lain", "Lain"], ["anime", "Anime"], ["abstract", T.t("Abstrait")], ["ascii", "ASCII"],
                               ["minimal", "Minimal"], ["fruit", T.t("Fruits")], ["espace", T.t("Espace")], ["distros", "Distros"], ["genere", T.t("Générés")], ["live", T.t("Animés")]]
  property string cat: "all"
  property var all: []
  // Filtre couleur (une teinte dominante par fond, calculée par `liquid-glass wall-colors`)
  // et recherche par nom (touche /).
  readonly property var swatches: [["rouge", "#e0463c"], ["orange", "#f0902c"], ["jaune", "#f2cf3a"], ["vert", "#4bb565"],
                                   ["cyan", "#3cc3cf"], ["bleu", "#3f7ae8"], ["violet", "#8f5be0"], ["rose", "#ec6aae"],
                                   ["sombre", "#16161c"], ["clair", "#f1f1ec"]]
  property string tint: ""
  property string query: ""
  property bool searching: false
  property var tints: ({})
  FileView {
    id: tintFile
    path: win.home + "/.cache/liquid-glass/wall-colors.json"
    printErrors: false
    onLoaded: { try { win.tints = JSON.parse(text()) } catch (e) { win.tints = {} } }
  }
  Process {
    id: tintScan
    running: true
    command: ["liquid-glass", "wall-colors"]
    onExited: tintFile.reload()
  }
  readonly property var items: {
    var out = [], q = query.toLowerCase()
    for (var i = 0; i < all.length; i++) {
      var it = all[i]
      if (cat !== "all" && it.cat !== cat) continue
      if (tint !== "" && tints[it.path] !== tint) continue
      if (q !== "" && it.name.toLowerCase().indexOf(q) < 0 && it.cat.indexOf(q) < 0) continue
      out.push(it)
    }
    return out
  }
  property int current: 0
  property real pos: 0
  Behavior on pos { SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.002 } }
  onCurrentChanged: pos = current
  onItemsChanged: { current = Math.max(0, Math.min(current, items.length - 1)); pos = current }

  property bool shown: false
  Component.onCompleted: { list.running = true; shown = true; keys.forceActiveFocus() }

  Process {
    id: list
    command: ["bash", "-c",
      "for f in \"$HOME\"/.config/omarchy/themes/lain/backgrounds/* " +
      "  \"$HOME\"/.config/omarchy/themes/{blanc,sombre,jouet,violet,violet-aube,rose,windows,windows-sombre,mono,mono-papier,mono-sakura,foret,ruban,espace,debian,fedora,mint,kali,arch}/backgrounds/* " +
      "  \"$HOME\"/.local/share/liquid-glass/wallpapers/* \"$HOME\"/.local/share/liquid-glass/live/*; do " +
      "  case \"$f\" in *.jpg|*.jpeg|*.png|*.webp|*.JPG|*.PNG|*.mp4) [ -f \"$f\" ] && echo \"$f\";; esac; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = [], lines = text.split("\n"), cur = String(win.s.bgPath || ""), idx = 0
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].trim()
          if (f === "") continue
          var name = f.split("/").pop()
          var live = f.indexOf("/liquid-glass/live/") >= 0
          var c = live ? "live" : f.indexOf("/themes/lain/") >= 0 ? "lain" : f.indexOf("/themes/espace/") >= 0 ? "espace"
            : /\/themes\/(debian|fedora|mint|kali|arch)\//.test(f) ? "distros" : (f.indexOf("/omarchy/themes/") >= 0 ? "genere" : name.split("-")[0])
          // Fonds animés (scripts/fetch-live-wallpapers.py) : l'affiche de la vidéo.
          var thumb = live ? win.home + "/.cache/liquid-glass/posters/" + name.replace(/\.mp4$/, ".jpg")
            : f.indexOf("/liquid-glass/wallpapers/") >= 0 ? win.home + "/.cache/liquid-glass/thumbs/" + name : ""
          if (f === cur) idx = out.length
          out.push({ path: f, name: name.replace(/\.[^.]+$/, ""), cat: c, thumb: thumb })
        }
        win.all = out
        win.current = idx
        win.pos = idx
      }
    }
  }

  function close() { shown = false; closeTimer.start() }
  Timer { id: closeTimer; interval: 260; onTriggered: win.s.wallsOpen = false }
  function apply() {
    var it = items[current]
    if (!it) return
    Quickshell.execDetached(["omarchy-theme-bg-set", it.path])
    close()
  }
  function step(n) { if (items.length) current = Math.max(0, Math.min(items.length - 1, current + n)) }

  // Fond : voile sombre, clic = fermer.
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    opacity: win.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 240 } }
    MouseArea { anchors.fill: parent; onClicked: win.close() }
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(e) {
      if (win.searching) {
        if (e.key === Qt.Key_Escape) { win.searching = false; win.query = "" }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.searching = false
        else if (e.key === Qt.Key_Backspace) win.query = win.query.slice(0, -1)
        else if (e.key === Qt.Key_Left) win.step(-1)
        else if (e.key === Qt.Key_Right) win.step(1)
        else if (e.text !== "" && e.text.charCodeAt(0) >= 32) win.query += e.text
        else return
        e.accepted = true
        return
      }
      if (e.key === Qt.Key_Slash || e.text === "/") { win.searching = true; win.query = "" }
      else if (e.key === Qt.Key_Escape) win.close()
      else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) win.step(-1)
      else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) win.step(1)
      else if (e.key === Qt.Key_PageUp) win.step(-6)
      else if (e.key === Qt.Key_PageDown) win.step(6)
      else if (e.key === Qt.Key_Home) win.current = 0
      else if (e.key === Qt.Key_End) win.current = Math.max(0, win.items.length - 1)
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) win.apply()
      else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
        var i = 0
        for (var k = 0; k < win.cats.length; k++) if (win.cats[k][0] === win.cat) i = k
        i = (i + (e.key === Qt.Key_Backtab ? -1 : 1) + win.cats.length) % win.cats.length
        win.cat = win.cats[i][0]
      } else return
      e.accepted = true
    }
  }

  Item {
    id: stage
    anchors.fill: parent
    opacity: win.shown ? 1 : 0
    property real lift: win.shown ? 0 : 60
    Behavior on opacity { NumberAnimation { duration: 260 } }
    Behavior on lift { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
    transform: Translate { y: stage.lift }

    // Barre d'outils : catégories, hasard, compteur.
    Rectangle {
      id: toolbar
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.5 - 196)
      height: 36
      width: tbRow.implicitWidth + 12
      radius: 12
      color: win.s.surfaceMid
      border.width: 1
      border.color: win.s.alpha(win.s.outlineVariant, 0.5)
      Row {
        id: tbRow
        anchors.centerIn: parent
        spacing: 4
        Repeater {
          model: win.cats
          delegate: Rectangle {
            required property var modelData
            readonly property bool on: win.cat === modelData[0]
            height: 26
            width: chipText.implicitWidth + 20
            radius: 8
            color: on ? win.s.primary : (chipMouse.containsMouse ? win.s.surfaceHighest : win.s.surfaceHigh)
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
              id: chipText
              anchors.centerIn: parent
              text: parent.modelData[1]
              font.family: win.s.sansFont
              font.pixelSize: 12
              font.weight: Font.Medium
              color: parent.on ? win.s.colOnPrimary : win.s.colOnSurface
            }
            MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.cat = parent.modelData[0] }
          }
        }
        Rectangle {
          height: 26; width: 30; radius: 8
          color: shufMouse.containsMouse ? win.s.surfaceHighest : win.s.surfaceHigh
          MIcon { anchors.centerIn: parent; icon: "shuffle"; size: 16; color: win.s.colOnSurface }
          MouseArea { id: shufMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.current = Math.floor(Math.random() * win.items.length) }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: 4; rightPadding: 6
          text: win.items.length ? (win.current + 1) + " / " + win.items.length : "…"
          font.family: win.s.numFont
          font.pixelSize: 11
          color: win.s.colOnSurfaceVariant
        }
      }
    }

    // Les cartes
    Item {
      id: deck
      anchors.fill: parent
      readonly property real cx: width / 2
      readonly property real cy: height / 2 + 30
      readonly property real bigW: Math.min(420, width * 0.34)
      readonly property real smallW: 96
      readonly property real gap: 12
      readonly property real skew: -0.2
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(w) { win.step((w.angleDelta.y || -w.angleDelta.x) > 0 ? -1 : 1) }
      }
      Repeater {
        model: win.items
        delegate: Item {
          id: card
          required property var modelData
          required property int index
          readonly property real d: index - win.pos
          readonly property real ad: Math.abs(d)
          readonly property bool near: ad < 7.5
          visible: near
          readonly property real w: deck.bigW + (deck.smallW - deck.bigW) * Math.min(1, ad)
          readonly property real h: 300 - Math.min(1, ad) * 46 - Math.max(0, ad - 1) * 14
          readonly property real off: ad <= 1 ? ad * (deck.bigW / 2 + deck.gap + deck.smallW / 2)
                                              : (deck.bigW / 2 + deck.gap + deck.smallW / 2) + (ad - 1) * (deck.smallW + deck.gap)
          x: deck.cx + (d < 0 ? -off : off) - w / 2
          y: deck.cy - h / 2
          width: w
          height: h
          z: 100 - ad
          opacity: Math.max(0, Math.min(1, 7 - ad))
          transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, deck.skew, 0, -deck.skew * card.h / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
          }
          ClippingRectangle {
            anchors.fill: parent
            radius: 14
            color: win.s.surfaceHigh
            border.width: card.index === win.current ? 2 : 0
            border.color: win.s.primary
            // Sans taille propre : un Loader dimensionné redimensionnerait l'image.
            Loader {
              active: card.near
              sourceComponent: Image {
                // Contre-inclinaison : la photo reste droite dans la carte penchée.
                x: -deck.bigW * 0.12
                width: card.width + deck.bigW * 0.24
                height: card.height
                source: "file://" + (card.modelData.thumb !== "" ? card.modelData.thumb : card.modelData.path)
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                transform: Matrix4x4 {
                  matrix: Qt.matrix4x4(1, -deck.skew, 0, deck.skew * card.h / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }
              }
            }
            // Voile sur les cartes latérales.
            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(0, 0, 0, Math.min(0.45, card.ad * 0.12))
            }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (card.index === win.current) win.apply(); else win.current = card.index }
          }
        }
      }

      // Filtres : pastilles de couleur et recherche.
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: deck.cy + 150 + 54
        spacing: 8
        Repeater {
          model: win.swatches
          delegate: Rectangle {
            id: sw
            required property var modelData
            readonly property bool on: win.tint === modelData[0]
            anchors.verticalCenter: parent.verticalCenter
            width: on ? 28 : 22; height: width; radius: width / 2
            color: modelData[1]
            border.width: on ? 2 : 1; border.color: on ? "white" : Qt.rgba(1, 1, 1, 0.3)
            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: win.tint = sw.on ? "" : sw.modelData[0] }
          }
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(120, sRow.implicitWidth + 20); height: 28; radius: 14
          color: win.searching ? win.s.primary : win.s.surfaceMid
          Row {
            id: sRow
            anchors.centerIn: parent; spacing: 5
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 14; color: win.searching ? win.s.colOnPrimary : win.s.colOnSurfaceVariant }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: win.query !== "" ? win.query : (win.searching ? T.t("Tape un nom") : T.t("Touche /"))
              font.family: win.s.sansFont; font.pixelSize: 12
              color: win.searching ? win.s.colOnPrimary : win.s.colOnSurfaceVariant
            }
          }
          MouseArea { anchors.fill: parent; onClicked: { win.searching = !win.searching; if (!win.searching) win.query = "" } }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: win.items.length + (win.items.length > 1 ? T.t(" fonds") : T.t(" fond"))
          font.family: win.s.sansFont; font.pixelSize: 11; color: "white"
        }
      }

      // Nom du fond sélectionné
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: deck.cy + 150 + 18
        height: 26
        width: nameRow.implicitWidth + 22
        radius: 13
        color: win.s.surfaceMid
        visible: win.items.length > 0
        Row {
          id: nameRow
          anchors.centerIn: parent
          spacing: 6
          MIcon { icon: "wallpaper"; size: 14; color: win.s.primary; anchors.verticalCenter: parent.verticalCenter }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: win.items[win.current] ? win.items[win.current].name : ""
            font.family: win.s.sansFont
            font.pixelSize: 12
            color: win.s.colOnSurface
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: T.t("Entrée pour appliquer")
            font.family: win.s.sansFont
            font.pixelSize: 11
            color: win.s.colOnSurfaceVariant
          }
        }
      }
    }
  }
}
