import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// La scène musicale du bureau Linux, posée sur le fond, sous les widgets :
//  • visualiseur cava (Réglages → Musique) : barres, vague pleine (Serpantinum),
//    miroir, blocs pixel (Jouet), ligne d'oscilloscope, ou anneau radial ;
//  • halo qui respire avec les basses ;
//  • paroles géantes : le mot chanté en énorme police pixel (comme les rices
//    TikTok), ou la ligne entière.
// Ne prend aucun clic (mask vide) : tout passe au bureau et aux widgets.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-linux-music"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  readonly property bool live: s.cavaValues.length > 0
  readonly property var vals: s.cavaValues
  readonly property int n: vals.length > 0 ? vals.length : s.cavaBars
  function v(i) { return i < vals.length ? vals[i] / 100 : 0 }

  // ------------------------------------------------------------ halo
  Rectangle {
    visible: win.s.pulse
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: parent.height * 0.55
    opacity: Math.min(1, win.s.beat * 1.3)
    gradient: Gradient {
      GradientStop { position: 0; color: "transparent" }
      GradientStop { position: 1; color: win.s.alpha(win.s.vizColor(0, 1), win.s.darkSkin ? 0.28 : 0.16) }
    }
  }

  // ------------------------------------------------------------ visualiseur
  Item {
    id: viz
    visible: win.s.showCava && win.s.vizMode !== "off" && win.s.vizMode !== "radial"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    height: win.s.vizHeight
    opacity: win.live ? win.s.vizOpacity : 0
    Behavior on opacity { NumberAnimation { duration: 500 } }
    readonly property real slot: width / win.n

    // Barres (et miroir : de part et d'autre d'une ligne médiane)
    Repeater {
      model: win.s.vizMode === "bars" || win.s.vizMode === "mirror" ? win.n : 0
      delegate: Rectangle {
        required property int index
        readonly property bool mirror: win.s.vizMode === "mirror"
        property real h: Math.max(2, viz.height * win.v(index) * (mirror ? 0.5 : 0.96))
        x: index * viz.slot + viz.slot * 0.18
        width: Math.max(2, viz.slot * 0.64)
        height: mirror ? h * 2 : h
        y: mirror ? viz.height / 2 - h : viz.height - h
        radius: win.s.style === "blanc" || win.s.style === "sombre" ? 0 : width / 2
        color: win.s.vizColor(index, win.n)
        Behavior on h { NumberAnimation { duration: 60 } }
      }
    }

    // Blocs pixel empilés (style Jouet / sombre rétro)
    Repeater {
      model: win.s.vizMode === "blocks" ? win.n : 0
      delegate: Column {
        id: col
        required property int index
        readonly property int rows: Math.max(4, Math.floor(viz.height / (cell + 3)))
        readonly property real cell: Math.max(4, Math.min(16, viz.slot * 0.7))
        readonly property int lit: Math.round(win.v(index) * rows)
        x: index * viz.slot + (viz.slot - cell) / 2
        anchors.bottom: parent.bottom
        spacing: 3
        Repeater {
          model: col.rows
          delegate: Rectangle {
            required property int index
            width: col.cell
            height: col.cell
            radius: win.s.style === "jouet" ? 3 : 0
            color: win.s.vizColor(col.index, win.n)
            opacity: (col.rows - 1 - index) < col.lit ? 1 : 0.07
          }
        }
      }
    }

    // Vague pleine (Serpantinum) ou ligne d'oscilloscope
    Shape {
      anchors.fill: parent
      visible: win.s.vizMode === "wave" || win.s.vizMode === "line"
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: win.s.vizMode === "line" ? win.s.vizColor(0, 1) : "transparent"
        strokeWidth: win.s.vizMode === "line" ? 2.5 : -1
        fillColor: win.s.vizMode === "wave" ? win.s.alpha(win.s.vizColor(0, 1), 0.85) : "transparent"
        joinStyle: ShapePath.RoundJoin
        PathPolyline {
          path: {
            var pts = [], w = viz.width, h = viz.height, N = win.n, line = win.s.vizMode === "line"
            if (!line) pts.push(Qt.point(0, h))
            // Interpolation douce entre les barres (cosinus), 4 points par barre.
            var steps = Math.max(2, N * 4)
            for (var k = 0; k <= steps; k++) {
              var f = k / steps * (N - 1), i0 = Math.floor(f), i1 = Math.min(N - 1, i0 + 1), t = f - i0
              var m = (1 - Math.cos(t * Math.PI)) / 2
              var val = win.v(i0) * (1 - m) + win.v(i1) * m
              var y = line ? h / 2 + Math.sin(k * 1.7) * val * h * 0.45
                           : h - Math.max(2, val * h * 0.95)
              pts.push(Qt.point(k / steps * w, y))
            }
            if (!line) pts.push(Qt.point(w, h))
            return pts
          }
        }
      }
    }
  }

  // Anneau radial au centre de l'écran, autour des paroles
  Item {
    id: radial
    visible: win.s.showCava && win.s.vizMode === "radial"
    width: Math.min(parent.width, parent.height) * 0.62
    height: width
    anchors.centerIn: parent
    opacity: win.live ? win.s.vizOpacity : 0
    Behavior on opacity { NumberAnimation { duration: 500 } }
    readonly property real r0: width * 0.3
    Repeater {
      model: radial.visible ? win.n : 0
      delegate: Rectangle {
        required property int index
        readonly property real ang: index / win.n * 360
        readonly property real len: 4 + win.v(index) * radial.width * 0.2
        width: 3
        height: len
        radius: 1.5
        color: win.s.vizColor(index, win.n)
        x: radial.width / 2 - width / 2
        y: radial.height / 2 - radial.r0 - len
        transform: Rotation { origin.x: 1.5; origin.y: radial.r0 + len; angle: ang }
      }
    }
  }

  // ------------------------------------------------------------ paroles géantes
  Item {
    id: lyr
    visible: win.s.showLyrics && (win.s.lyricsMode === "word" || win.s.lyricsMode === "line")
    anchors.fill: parent
    opacity: win.s.playing && (win.s.lyricsMode === "word" ? win.s.word !== "" : win.s.line !== "") ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 400 } }
    readonly property real cy: win.s.lyricsPos === "top" ? parent.height * 0.24 : parent.height * 0.42
    readonly property bool atLeft: win.s.lyricsPos === "left"

    // Le mot chanté
    Text {
      id: bigWord
      visible: win.s.lyricsMode === "word"
      text: win.s.word.toUpperCase()
      x: lyr.atLeft ? parent.width * 0.06 : (parent.width - width) / 2
      y: lyr.cy - height / 2
      font.family: win.s.pixelFont
      font.weight: Font.Bold
      font.pixelSize: Math.round(Math.min(150, parent.width / Math.max(4, text.length + 1) * 1.15) * win.s.lyricsScale)
      color: win.s.style === "jouet" ? win.s.rainbow[Math.max(0, win.s.wordIndex) % win.s.rainbow.length] : win.s.colOnSurface
      style: win.s.style === "jouet" ? Text.Outline : Text.Normal
      styleColor: "#1b1030"
      transformOrigin: Item.Center
      property real pop: 1
      property real tilt: 0
      scale: pop * (1 + (win.s.bump ? win.s.beat * 0.08 : 0))
      rotation: tilt
      onTextChanged: {
        pop = 1.32
        tilt = win.s.style === "jouet" ? (Math.random() * 12 - 6) : 0
        popAnim.restart()
      }
      NumberAnimation { id: popAnim; target: bigWord; property: "pop"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }
    // La suite de la ligne, en petit dessous (repère pour suivre)
    Text {
      visible: win.s.lyricsMode === "word" && win.s.line !== ""
      x: lyr.atLeft ? parent.width * 0.06 : (parent.width - width) / 2
      y: bigWord.y + bigWord.height + 6
      width: Math.min(parent.width * 0.7, implicitWidth)
      elide: Text.ElideRight
      text: win.s.line
      font.family: win.s.sansFont
      font.pixelSize: 15
      color: win.s.alpha(win.s.colOnSurface, 0.55)
    }

    // La ligne entière
    Column {
      visible: win.s.lyricsMode === "line"
      x: lyr.atLeft ? parent.width * 0.06 : (parent.width - width) / 2
      y: lyr.cy - height / 2
      width: parent.width * 0.72
      spacing: 10
      Text {
        id: lineText
        width: parent.width
        horizontalAlignment: lyr.atLeft ? Text.AlignLeft : Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: win.s.line
        font.family: win.s.displayFont
        font.weight: Font.Bold
        font.pixelSize: Math.round(46 * win.s.lyricsScale)
        color: win.s.colOnSurface
        scale: 1 + (win.s.bump ? win.s.beat * 0.04 : 0)
        onTextChanged: lineFade.restart()
        NumberAnimation { id: lineFade; target: lineText; property: "opacity"; from: 0; to: 1; duration: 350 }
      }
      Text {
        width: parent.width
        horizontalAlignment: lyr.atLeft ? Text.AlignLeft : Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: win.s.lineIndex + 1 < win.s.lyrics.length ? String(win.s.lyrics[win.s.lineIndex + 1].text || "") : ""
        font.family: win.s.sansFont
        font.pixelSize: Math.round(18 * win.s.lyricsScale)
        color: win.s.alpha(win.s.colOnSurface, 0.45)
      }
    }
  }
}
