import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Widget « lecture en cours » libre sur le bureau.
// Fenêtre « Bottom » de tout l'écran, mais seule la carte (et sa pastille de
// taille) reçoit les clics grâce au masque : le reste du bureau fonctionne.
//   • aucun repère visible : lâché, il s'aimante sur des axes x / y
//     invisibles (la grille des widgets, alignée sur la colonne de gauche,
//     sur les bords droit / bas et sur le centre de l'écran) ;
//   • lâché en mouvement, il glisse comme sur une patinoire (inertie, friction
//     faible) et rebondit sur les bords de l'écran ;
//   • il s'incline selon la vitesse, gonfle quand on l'attrape, s'écrase en
//     touchant un bord, et fait un rebond élastique quand on change sa taille ;
//   • la position est enregistrée en fractions de l'écran (widgets.music_x /
//     music_y), la taille dans widgets.music_size.
PanelWindow {
  id: win
  property var service: null

  readonly property real unit: Style.space(150)
  readonly property real gap: Style.space(14)
  readonly property real margin: Style.space(10)
  // Mêmes marges que la colonne des widgets : les axes tombent juste.
  readonly property real edgeX: Style.space(22)
  readonly property real edgeY: Style.space(14)
  readonly property real step: unit + gap

  readonly property string size: service ? service.musicSize : "medium"
  readonly property real cardW: size === "small" ? unit : unit * 2 + gap
  readonly property real cardH: size === "large" ? unit * 2 + gap : unit

  readonly property bool shown: !!service && service.showMusic && service.hasTrack
  property bool lyricsMode: false

  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "liquid-glass-widgets"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  visible: holder.opacity > 0.01
  mask: Region {
    item: holder
    Region { item: sizePill }
  }

  // ------------------------------------------------------------ position
  readonly property real minX: edgeX
  readonly property real minY: edgeY
  readonly property real maxX: Math.max(minX, width - cardW - edgeX)
  readonly property real maxY: Math.max(minY, height - cardH - edgeY)

  // Axes d'aimantation sur une dimension : les bords, le centre, et les pas de
  // la grille comptés depuis chaque bord. Renvoie le plus proche de v.
  function snapAxis(v, lo, hi) {
    var c = [lo, hi, Math.round((lo + hi) / 2)]
    for (var a = lo + step; a < hi - 1; a += step) c.push(a)
    for (var b = hi - step; b > lo + 1; b -= step) c.push(b)
    var best = c[0]
    for (var i = 1; i < c.length; i++) if (Math.abs(c[i] - v) < Math.abs(best - v)) best = c[i]
    return best
  }
  function clampX(x) { return Math.max(minX, Math.min(maxX, x)) }
  function clampY(y) { return Math.max(minY, Math.min(maxY, y)) }

  // Position = fractions de l'espace libre (fx, fy ∈ [0, 1]) : un widget collé
  // à droite le reste quand il change de taille ou que l'écran change.
  // -1 : jamais posé, on part de l'ancienne ancre music_position.
  function anchorFrac(horizontal) {
    var n = service ? service.musicPosition : "bottom-left"
    if (horizontal) return n.indexOf("right") !== -1 ? 1 : (n.indexOf("left") !== -1 ? 0 : 0.5)
    return n.indexOf("top") === 0 ? 0 : (n.indexOf("bottom") === 0 ? 1 : 0.5)
  }
  property real fx: service && service.musicX >= 0 ? service.musicX : anchorFrac(true)
  property real fy: service && service.musicY >= 0 ? service.musicY : anchorFrac(false)
  Connections {
    target: win.service
    function onMusicXChanged() { if (win.service.musicX >= 0 && !drag.active && !glide.running) win.fx = win.service.musicX }
    function onMusicYChanged() { if (win.service.musicY >= 0 && !drag.active && !glide.running) win.fy = win.service.musicY }
  }
  readonly property real restX: minX + Math.max(0, Math.min(1, fx)) * (maxX - minX)
  readonly property real restY: minY + Math.max(0, Math.min(1, fy)) * (maxY - minY)

  // Fin de geste : on retient l'endroit, on se raccroche à la liaison, on enregistre.
  function commit() {
    var sx = snapAxis(holder.x, minX, maxX), sy = snapAxis(holder.y, minY, maxY)
    fx = maxX > minX ? (sx - minX) / (maxX - minX) : 0
    fy = maxY > minY ? (sy - minY) / (maxY - minY) : 0
    fx = Math.round(Math.max(0, Math.min(1, fx)) * 10000) / 10000
    fy = Math.round(Math.max(0, Math.min(1, fy)) * 10000) / 10000
    holder.x = Qt.binding(function() { return win.restX })
    holder.y = Qt.binding(function() { return win.restY })
    if (service) service.setOptions({ music_x: fx, music_y: fy })
  }

  // Changement de taille : rebond élastique (la taille change d'un coup, sans
  // animer largeur/hauteur, pour que masque, contenu et position restent alignés).
  onSizeChanged: popAnim.restart()
  SequentialAnimation {
    id: popAnim
    NumberAnimation { target: holder; property: "pop"; to: 0.78; duration: 90; easing.type: Easing.InQuad }
    NumberAnimation { target: holder; property: "pop"; to: 1; duration: 900; easing.type: Easing.OutElastic; easing.amplitude: 1.3; easing.period: 0.32 }
  }

  // ------------------------------------------------------- glisse (patinoire)
  property real vx: 0
  property real vy: 0
  property var samples: []
  readonly property real friction: 1.9      // décroissance de la vitesse (1/s) : faible = glisse loin
  readonly property real restitution: 0.62  // part de la vitesse gardée au rebond
  readonly property real maxSpeed: 3200

  FrameAnimation {
    id: glide
    running: false
    onTriggered: {
      var dt = Math.min(0.05, frameTime)
      var k = Math.exp(-win.friction * dt)
      win.vx *= k; win.vy *= k
      var nx = holder.x + win.vx * dt, ny = holder.y + win.vy * dt
      if (nx < win.minX || nx > win.maxX) {
        nx = win.clampX(nx)
        win.vx = -win.vx * win.restitution
        holder.bump(true, Math.abs(win.vx))
      }
      if (ny < win.minY || ny > win.maxY) {
        ny = win.clampY(ny)
        win.vy = -win.vy * win.restitution
        holder.bump(false, Math.abs(win.vy))
      }
      holder.x = nx; holder.y = ny
      if (Math.abs(win.vx) < 6 && Math.abs(win.vy) < 6) {
        win.vx = 0; win.vy = 0
        stop()
        landAnim.restart()
        win.commit()
      }
    }
  }

  // --------------------------------------------------------------- carte
  Item {
    id: holder
    width: win.cardW; height: win.cardH
    x: win.restX
    y: win.restY
    z: 2
    // Repositionnement (taille, écran, config) : glissé avec dépassement.
    // Aimantation / repositionnement : il file vers l'axe et le dépasse avant de se caler.
    Behavior on x { enabled: !drag.active && !glide.running; NumberAnimation { duration: 720; easing.type: Easing.OutBack; easing.overshoot: 2.8 } }
    Behavior on y { enabled: !drag.active && !glide.running; NumberAnimation { duration: 720; easing.type: Easing.OutBack; easing.overshoot: 2.8 } }

    // Échelles composées : apparition × prise en main × rebond de taille × écrasement.
    property real appear: win.shown ? 1 : 0.55
    property real lift: drag.active ? 1.09 : 1
    property real pop: 1
    property real squashX: 1
    property real squashY: 1
    Behavior on appear { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
    Behavior on lift { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }

    opacity: win.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    // Inclinaison selon la vitesse horizontale, avec un ressort mou.
    readonly property real tiltTarget: Math.max(-12, Math.min(12, (drag.active || glide.running) ? win.vx * 0.006 : 0))
    rotation: tiltTarget
    Behavior on rotation { SpringAnimation { spring: 2.6; damping: 0.18; epsilon: 0.05 } }

    transform: Scale {
      origin.x: holder.width / 2; origin.y: holder.height / 2
      xScale: holder.appear * holder.lift * holder.pop * holder.squashX
      yScale: holder.appear * holder.lift * holder.pop * holder.squashY
    }

    // Choc contre un bord : écrasement dans l'axe du choc, proportionnel à la vitesse.
    function bump(horizontal, speed) {
      var s = Math.min(0.22, speed / 6000)
      if (s < 0.02) return
      squashAnim.stop()
      squashX = horizontal ? 1 - s : 1 + s * 0.6
      squashY = horizontal ? 1 + s * 0.6 : 1 - s
      squashAnim.restart()
    }
    ParallelAnimation {
      id: squashAnim
      NumberAnimation { target: holder; property: "squashX"; to: 1; duration: 620; easing.type: Easing.OutElastic; easing.amplitude: 1.4; easing.period: 0.3 }
      NumberAnimation { target: holder; property: "squashY"; to: 1; duration: 620; easing.type: Easing.OutElastic; easing.amplitude: 1.4; easing.period: 0.3 }
    }
    // Arrêt : petit tassement puis rebond.
    SequentialAnimation {
      id: landAnim
      ParallelAnimation {
        NumberAnimation { target: holder; property: "squashY"; to: 0.93; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: holder; property: "squashX"; to: 1.05; duration: 90; easing.type: Easing.OutQuad }
      }
      ParallelAnimation {
        NumberAnimation { target: holder; property: "squashY"; to: 1; duration: 700; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.3 }
        NumberAnimation { target: holder; property: "squashX"; to: 1; duration: 700; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.3 }
      }
    }

    MusicWidget {
      id: card
      anchors.fill: parent
      svc: win.service
      size: win.size
      lyricsMode: win.lyricsMode
      onLyricsToggled: flipAnim.restart()
      transform: Rotation {
        id: flip
        origin.x: card.width / 2; origin.y: card.height / 2
        axis { x: 0; y: 1; z: 0 }
        angle: 0
      }
    }
    // Bascule paroles ↔ pochette : la carte se retourne.
    SequentialAnimation {
      id: flipAnim
      NumberAnimation { target: flip; property: "angle"; from: 0; to: 90; duration: 170; easing.type: Easing.InCubic }
      ScriptAction { script: win.lyricsMode = !win.lyricsMode }
      NumberAnimation { target: flip; property: "angle"; from: -90; to: 0; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }

    // Glisser n'importe où sur la carte ; les boutons gardent leurs clics
    // (le glissement ne démarre qu'après le seuil de déplacement).
    DragHandler {
      id: drag
      target: null
      cursorShape: Qt.ClosedHandCursor
      property real sx: 0
      property real sy: 0
      onActiveChanged: {
        if (active) {
          glide.stop(); landAnim.stop()
          sx = holder.x; sy = holder.y
          win.vx = 0; win.vy = 0
          win.samples = []
          return
        }
        // Vitesse au lâcher : moyenne sur les ~90 dernières ms.
        var s = win.samples, now = Date.now()
        while (s.length > 1 && now - s[0].t > 90) s.shift()
        if (s.length > 1 && now - s[s.length - 1].t < 60) {
          var dt = Math.max(0.016, (s[s.length - 1].t - s[0].t) / 1000)
          win.vx = (s[s.length - 1].x - s[0].x) / dt
          win.vy = (s[s.length - 1].y - s[0].y) / dt
          var sp = Math.hypot(win.vx, win.vy)
          if (sp > win.maxSpeed) { win.vx *= win.maxSpeed / sp; win.vy *= win.maxSpeed / sp }
        } else {
          win.vx = 0; win.vy = 0
        }
        if (Math.hypot(win.vx, win.vy) > 40) glide.start()
        else { win.vx = 0; win.vy = 0; landAnim.restart(); win.commit() }
      }
      onActiveTranslationChanged: {
        if (!active) return
        // Hors des bords, la carte résiste (élastique) au lieu de s'arrêter net.
        var rx = sx + activeTranslation.x, ry = sy + activeTranslation.y
        function rubber(v, lo, hi) {
          if (v < lo) return lo - Math.sqrt(lo - v) * 4
          if (v > hi) return hi + Math.sqrt(v - hi) * 4
          return v
        }
        holder.x = rubber(rx, win.minX, win.maxX)
        holder.y = rubber(ry, win.minY, win.maxY)
        var now = Date.now(), s = win.samples
        s.push({ t: now, x: rx, y: ry })
        while (s.length > 12) s.shift()
        // Vitesse instantanée lissée, pour l'inclinaison pendant le glissement.
        if (s.length > 1) {
          var a = s[Math.max(0, s.length - 4)], b = s[s.length - 1]
          var dt = Math.max(0.008, (b.t - a.t) / 1000)
          win.vx = win.vx * 0.5 + ((b.x - a.x) / dt) * 0.5
        }
      }
    }
    HoverHandler { id: hover }

    // Pastille de taille, au survol.
    Rectangle {
      id: sizePill
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.bottom
      width: pillRow.implicitWidth + 8; height: Style.space(26); radius: height / 2
      color: Qt.rgba(0, 0, 0, 0.5)
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
      readonly property bool on: (hover.hovered || pillHover.hovered) && !drag.active && !glide.running
      opacity: on ? 1 : 0
      scale: on ? 1 : 0.4
      visible: opacity > 0.01
      Behavior on opacity { NumberAnimation { duration: 180 } }
      Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 } }
      HoverHandler { id: pillHover }
      Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 2
        Repeater {
          model: [["small", "S"], ["medium", "M"], ["large", "L"]]
          delegate: Rectangle {
            required property var modelData
            readonly property bool on: win.size === modelData[0]
            width: Style.space(28); height: sizePill.height - 6; radius: height / 2
            color: on ? Qt.rgba(1, 1, 1, 0.88) : (pm.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent")
            scale: pm.pressed ? 0.75 : 1
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
            Behavior on color { ColorAnimation { duration: 140 } }
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: parent.modelData[1]
              font.family: card.font; font.pixelSize: Style.space(11); font.weight: Font.DemiBold
              color: parent.on ? "#1d1d1f" : "white"
            }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (win.service) win.service.setOption("music_size", parent.modelData[0]) }
          }
        }
      }
    }
  }
}
