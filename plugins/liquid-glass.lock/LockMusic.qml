import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons

// Widget musique de l'écran de verrouillage, comme dans macOS Tahoe :
//   • compact : petite carte de verre (pochette, titre, artiste, progression,
//     ⏮ ⏯ ⏭ et la bulle des paroles), juste au-dessus de l'avatar ;
//   • agrandi (bulle) : la pochette se déploie en grand carré, les commandes
//     passent dans une carte dessous, le fond devient la pochette floutée et
//     les paroles synchronisées défilent à côté.
// On le pose où on veut : il glisse avec de l'inertie (patinoire), rebondit
// sur les bords ; double-clic = retour à sa place par défaut.
// Position enregistrée dans lock.music_x / lock.music_y (fractions de l'écran).
Item {
  id: m
  property var view: null           // LockView
  property real topLimit: 0         // bas de l'horloge
  property real bottomLimit: height // haut de l'avatar
  property bool expanded: false
  signal toggled()

  readonly property var p: view ? view.player : null
  readonly property bool shown: !!view && view.musicActive && view.showMusicCard
  function g(cp) { return String.fromCodePoint(cp) }
  function refocus() { if (view) view.forcePasswordFocus() }

  // ------------------------------------------------------------- géométrie
  readonly property real artSide: 210
  readonly property real panelH: 84
  readonly property real cw: expanded ? artSide : 232
  readonly property real ch: expanded ? artSide + 10 + panelH : 98
  readonly property real minX: 14
  readonly property real minY: 14
  readonly property real maxX: Math.max(minX, width - cw - 14)
  readonly property real maxY: Math.max(minY, height - ch - 14)

  readonly property real defX: Math.round((width - cw) / 2)
  readonly property real defY: expanded
    ? Math.round(Math.max(topLimit + 8, (topLimit + bottomLimit) / 2 - ch / 2))
    : Math.round(bottomLimit - ch - 18)

  property real fx: view ? Number(view.lopt("music_x", -1)) : -1
  property real fy: view ? Number(view.lopt("music_y", -1)) : -1
  readonly property bool custom: fx >= 0 && fy >= 0
  readonly property real restX: custom ? minX + Math.min(1, fx) * (maxX - minX) : defX
  readonly property real restY: custom ? minY + Math.min(1, fy) * (maxY - minY) : defY

  Process { id: saver }
  function persist() {
    saver.command = ["liquid-glass", "set", "lock.music_x", String(fx), "lock.music_y", String(fy)]
    saver.running = true
  }
  function commit() {
    fx = maxX > minX ? Math.round((card.x - minX) / (maxX - minX) * 10000) / 10000 : 0
    fy = maxY > minY ? Math.round((card.y - minY) / (maxY - minY) * 10000) / 10000 : 0
    fx = Math.max(0, Math.min(1, fx)); fy = Math.max(0, Math.min(1, fy))
    card.x = Qt.binding(function() { return m.restX })
    card.y = Qt.binding(function() { return m.restY })
    persist()
  }
  function resetPlace() {
    fx = -1; fy = -1
    persist()
  }

  // ---------------------------------------------------------------- inertie
  property real vx: 0
  property real vy: 0
  property var samples: []
  FrameAnimation {
    id: glide
    onTriggered: {
      var dt = Math.min(0.05, frameTime)
      var k = Math.exp(-1.9 * dt)
      m.vx *= k; m.vy *= k
      var nx = card.x + m.vx * dt, ny = card.y + m.vy * dt
      if (nx < m.minX || nx > m.maxX) { nx = Math.max(m.minX, Math.min(m.maxX, nx)); m.vx = -m.vx * 0.62; card.bump(true, Math.abs(m.vx)) }
      if (ny < m.minY || ny > m.maxY) { ny = Math.max(m.minY, Math.min(m.maxY, ny)); m.vy = -m.vy * 0.62; card.bump(false, Math.abs(m.vy)) }
      card.x = nx; card.y = ny
      if (Math.abs(m.vx) < 6 && Math.abs(m.vy) < 6) { m.vx = 0; m.vy = 0; stop(); card.land(); m.commit() }
    }
  }

  // ---------------------------------------------------------------- paroles
  readonly property bool lyricsOn: expanded && view && view.showLyrics && view.lyricLines.length > 0
  readonly property bool lyricsRight: card.x + card.width / 2 <= width / 2 + 1
  Item {
    id: lyricsArea
    readonly property real w: Math.min(520, m.lyricsRight ? m.width - (card.x + card.width + 44) - 30 : card.x - 44 - 30)
    width: Math.max(0, w)
    height: Math.min(m.height * 0.5, 360)
    x: m.lyricsRight ? card.x + card.width + 44 : card.x - 44 - width
    y: Math.round(card.y + card.height / 2 - height / 2)
    opacity: m.lyricsOn && width > 160 ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 500 } }
    layer.enabled: true
    layer.effect: MultiEffect { maskEnabled: true; maskSource: lyricsFade; maskThresholdMin: 0.0; maskSpreadAtMin: 0.0 }
    // Les paroles arrivent en glissant depuis la pochette.
    transform: Translate {
      x: m.lyricsOn ? 0 : (m.lyricsRight ? -60 : 60)
      Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
    }
    LyricsColumn {
      anchors.fill: parent
      service: m.view ? m.view.lyricsModelRef : null
      fontFamily: m.view ? m.view.uiFont : "Inter"
      fontSize: 19
      horizontalAlignment: m.lyricsRight ? Text.AlignLeft : Text.AlignRight
      visibleRadius: 4
      blurPerLine: 0.22
    }
  }
  Item {
    id: lyricsFade
    width: lyricsArea.width; height: lyricsArea.height
    visible: false; layer.enabled: true
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.2; color: "black" }
        GradientStop { position: 0.8; color: "black" }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }
  }

  // ------------------------------------------------------------------ carte
  Item {
    id: card
    width: m.cw; height: m.ch
    x: m.restX; y: m.restY
    // Morphose compact ↔ agrandi et changements de place : ressort exagéré.
    Behavior on x { enabled: !drag.active && !glide.running; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
    Behavior on y { enabled: !drag.active && !glide.running; NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
    Behavior on width { NumberAnimation { duration: 650; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
    Behavior on height { NumberAnimation { duration: 650; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

    opacity: m.shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    property real appear: m.shown ? 1 : 0.6
    property real lift: drag.active ? 1.08 : 1
    property real squashX: 1
    property real squashY: 1
    Behavior on appear { NumberAnimation { duration: 750; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
    Behavior on lift { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
    rotation: Math.max(-12, Math.min(12, (drag.active || glide.running) ? m.vx * 0.006 : 0))
    Behavior on rotation { SpringAnimation { spring: 2.6; damping: 0.18; epsilon: 0.05 } }
    transform: Scale {
      origin.x: card.width / 2; origin.y: card.height / 2
      xScale: card.appear * card.lift * card.squashX
      yScale: card.appear * card.lift * card.squashY
    }
    function bump(horizontal, speed) {
      var s = Math.min(0.22, speed / 6000)
      if (s < 0.02) return
      squashX = horizontal ? 1 - s : 1 + s * 0.6
      squashY = horizontal ? 1 + s * 0.6 : 1 - s
      unsquash.restart()
    }
    function land() { landAnim.restart() }
    ParallelAnimation {
      id: unsquash
      NumberAnimation { target: card; property: "squashX"; to: 1; duration: 620; easing.type: Easing.OutElastic; easing.amplitude: 1.4; easing.period: 0.3 }
      NumberAnimation { target: card; property: "squashY"; to: 1; duration: 620; easing.type: Easing.OutElastic; easing.amplitude: 1.4; easing.period: 0.3 }
    }
    SequentialAnimation {
      id: landAnim
      ParallelAnimation {
        NumberAnimation { target: card; property: "squashY"; to: 0.93; duration: 90 }
        NumberAnimation { target: card; property: "squashX"; to: 1.05; duration: 90 }
      }
      ParallelAnimation {
        NumberAnimation { target: card; property: "squashY"; to: 1; duration: 700; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.3 }
        NumberAnimation { target: card; property: "squashX"; to: 1; duration: 700; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.3 }
      }
    }

    // Panneau de verre : toute la carte en compact, la bande du bas une fois agrandi.
    Rectangle {
      id: panel
      x: 0
      width: parent.width
      y: m.expanded ? m.artSide + 10 : 0
      height: m.expanded ? m.panelH : parent.height
      Behavior on y { NumberAnimation { duration: 650; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
      Behavior on height { NumberAnimation { duration: 650; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
      radius: 20
      color: Qt.rgba(1, 1, 1, 0.13)
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.30)
      Rectangle {
        anchors.fill: parent; anchors.margins: 1; radius: parent.radius - 1
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
          GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.0) }
        }
      }
    }

    // Pochette : vignette en compact, grand carré une fois agrandi.
    Item {
      id: art
      x: m.expanded ? 0 : 12
      y: m.expanded ? 0 : 11
      width: m.expanded ? m.artSide : 38
      height: width
      readonly property real r: m.expanded ? 18 : 8
      Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.7 } }
      Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.7 } }
      Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.7 } }
      Image { id: artImg; anchors.fill: parent; source: m.view ? m.view.coverSource : ""; sourceSize: Qt.size(480, 480); fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
      Item { id: artMask; anchors.fill: parent; visible: false; layer.enabled: true
        Rectangle { anchors.fill: parent; radius: art.r; color: "black" } }
      MultiEffect {
        anchors.fill: parent; source: artImg
        maskEnabled: true; maskSource: artMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
        shadowEnabled: m.expanded; shadowOpacity: 0.5; shadowBlur: 1.0; shadowVerticalOffset: 10
        visible: artImg.status === Image.Ready
      }
      Rectangle { anchors.fill: parent; radius: art.r; color: Qt.rgba(1, 1, 1, 0.2); visible: artImg.status !== Image.Ready }
      Rectangle { anchors.fill: parent; radius: art.r; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, m.expanded ? 0.22 : 0.0) }
    }

    // Titre / artiste : à droite de la vignette (compact), centrés dans le panneau (agrandi).
    Column {
      id: info
      x: m.expanded ? 12 : art.x + art.width + 10
      width: m.expanded ? card.width - 24 : card.width - x - 12
      y: panel.y + (m.expanded ? 9 : 12)
      Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
      spacing: 1
      Text {
        width: parent.width; textFormat: Text.PlainText; elide: Text.ElideRight
        horizontalAlignment: m.expanded ? Text.AlignHCenter : Text.AlignLeft
        text: m.p ? (m.p.trackTitle || "") : ""
        font.family: m.view ? m.view.uiFont : "Inter"; font.pixelSize: m.expanded ? 12 : 13; font.weight: Font.DemiBold
        color: "white"
      }
      Text {
        width: parent.width; textFormat: Text.PlainText; elide: Text.ElideRight
        horizontalAlignment: m.expanded ? Text.AlignHCenter : Text.AlignLeft
        text: m.p ? (m.p.trackArtist || "") : ""
        font.family: m.view ? m.view.uiFont : "Inter"; font.pixelSize: 11
        color: "white"; opacity: 0.68
      }
    }

    // Progression.
    Item {
      id: prog
      x: 12; width: card.width - 24; height: 12
      y: panel.y + panel.height - (m.expanded ? 46 : 46)
      readonly property real pos: m.view ? m.view.position : 0
      readonly property real len: m.view ? m.view.trackLength : 0
      Text { id: el; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 30; textFormat: Text.PlainText; text: m.view ? m.view.fmt(prog.pos) : ""; font.family: m.view ? m.view.uiFont : "Inter"; font.pixelSize: 9; font.features: { "tnum": 1 }; color: "white"; opacity: 0.6 }
      Text { id: rem; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 34; horizontalAlignment: Text.AlignRight; textFormat: Text.PlainText; text: prog.len > 0 && m.view ? "-" + m.view.fmt(prog.len - prog.pos) : ""; font.family: m.view ? m.view.uiFont : "Inter"; font.pixelSize: 9; font.features: { "tnum": 1 }; color: "white"; opacity: 0.6 }
      Rectangle {
        anchors.left: el.right; anchors.right: rem.left; anchors.leftMargin: 4; anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        height: barMouse.containsMouse ? 6 : 3; radius: height / 2
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        color: Qt.rgba(1, 1, 1, 0.22)
        Rectangle {
          width: prog.len > 0 ? parent.width * Math.min(1, prog.pos / prog.len) : 0
          height: parent.height; radius: height / 2; color: "white"
          Behavior on width { NumberAnimation { duration: 260 } }
        }
        MouseArea {
          id: barMouse
          anchors.fill: parent; anchors.margins: -7
          hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: function(ev) {
            if (m.p && m.p.canSeek && prog.len > 0) {
              m.p.position = Math.max(0, Math.min(1, (ev.x - 7) / (width - 14))) * prog.len
              m.view.updatePosition()
            }
            m.refocus()
          }
        }
      }
    }

    // ⏮ ⏯ ⏭ au centre, bulle des paroles à droite.
    Item {
      x: 8; width: card.width - 16; height: 28
      y: panel.y + panel.height - 32
      Row {
        anchors.centerIn: parent
        spacing: 14
        Btn { glyph: 0xF04AE; size: 16; act: function() { if (m.p && m.p.canGoPrevious) m.p.previous() } }
        Btn { glyph: m.p && m.p.isPlaying ? 0xF03E4 : 0xF040A; size: 20; act: function() { if (m.p) m.p.togglePlaying() } }
        Btn { glyph: 0xF04AD; size: 16; act: function() { if (m.p && m.p.canGoNext) m.p.next() } }
      }
      Rectangle {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 22; radius: 7
        color: Qt.rgba(1, 1, 1, m.expanded ? 0.85 : (bubble.containsMouse ? 0.28 : 0.16))
        Behavior on color { ColorAnimation { duration: 200 } }
        scale: bubble.pressed ? 0.75 : 1
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
        Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: m.g(0xF0369); font.family: Style.font.family; font.pixelSize: 13; color: m.expanded ? "#1d1d1f" : "white" }
        MouseArea { id: bubble; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { m.toggled(); m.refocus() } }
      }
    }

    DragHandler {
      id: drag
      target: null
      cursorShape: Qt.ClosedHandCursor
      property real sx: 0
      property real sy: 0
      onActiveChanged: {
        if (active) {
          glide.stop(); landAnim.stop()
          sx = card.x; sy = card.y
          m.vx = 0; m.vy = 0; m.samples = []
          return
        }
        var s = m.samples, now = Date.now()
        while (s.length > 1 && now - s[0].t > 90) s.shift()
        if (s.length > 1 && now - s[s.length - 1].t < 60) {
          var dt = Math.max(0.016, (s[s.length - 1].t - s[0].t) / 1000)
          m.vx = (s[s.length - 1].x - s[0].x) / dt
          m.vy = (s[s.length - 1].y - s[0].y) / dt
          var sp = Math.hypot(m.vx, m.vy)
          if (sp > 3200) { m.vx *= 3200 / sp; m.vy *= 3200 / sp }
        } else { m.vx = 0; m.vy = 0 }
        if (Math.hypot(m.vx, m.vy) > 40) glide.start()
        else { m.vx = 0; m.vy = 0; card.land(); m.commit() }
        m.refocus()
      }
      onActiveTranslationChanged: {
        if (!active) return
        var rx = sx + activeTranslation.x, ry = sy + activeTranslation.y
        function rubber(v, lo, hi) {
          if (v < lo) return lo - Math.sqrt(lo - v) * 4
          if (v > hi) return hi + Math.sqrt(v - hi) * 4
          return v
        }
        card.x = rubber(rx, m.minX, m.maxX)
        card.y = rubber(ry, m.minY, m.maxY)
        var now = Date.now(), s = m.samples
        s.push({ t: now, x: rx, y: ry })
        while (s.length > 12) s.shift()
        if (s.length > 1) {
          var a = s[Math.max(0, s.length - 4)], b = s[s.length - 1]
          var dt = Math.max(0.008, (b.t - a.t) / 1000)
          m.vx = m.vx * 0.5 + ((b.x - a.x) / dt) * 0.5
        }
      }
    }
    TapHandler {
      acceptedButtons: Qt.LeftButton
      onDoubleTapped: { m.resetPlace(); m.refocus() }
    }
  }

  component Btn: Item {
    id: b
    property int glyph: 0
    property real size: 16
    property var act: null
    width: size + 12; height: 26
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: m.g(b.glyph)
      font.family: Style.font.family; font.pixelSize: b.size
      color: "white"
      scale: bm.pressed ? 0.68 : (bm.containsMouse ? 1.15 : 1)
      Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
    }
    MouseArea { id: bm; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (b.act) b.act(); m.refocus() } }
  }
}
