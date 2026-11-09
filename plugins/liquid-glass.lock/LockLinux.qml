import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "T.js" as T

// ============================================================================
// Liquid Glass — écran de verrouillage du bureau Linux.
// Même interface que LockView.qml (propriétés, signaux, TextInput et ses
// gestionnaires) : Service.qml et le flux PAM ne changent pas, seul l'habillage.
//
// Au centre : grosse horloge « bonbon » empilée (heures sur minutes, chiffres
// alternés en deux tons), la date dans une pastille, le champ du mot de passe
// (cadenas, carrés qui apparaissent à chaque touche, flèche), l'utilisateur et la
// session. En bas : le morceau en cours ; à droite, clair/sombre (bascule en
// cercle qui s'ouvre depuis le bouton) et le menu d'alimentation.
// Les couleurs suivent le style Linux choisi ([linux] style / violet_tone).
// ============================================================================
Item {
  id: root

  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property bool errorState: failureMessage.length > 0
  readonly property bool video: Util.isVideoPath(root.backgroundPath)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() { passwordInput.forceActiveFocus() }
  function dropsAutoRepeat(key) { return key !== Qt.Key_Backspace && key !== Qt.Key_Delete }
  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }
  function restorePasswordFocus() {
    if (inputEnabled && passwordInput.enabled && !passwordInput.activeFocus) forcePasswordFocus()
  }
  onPasswordTextChanged: { syncPasswordText(); if (passwordText.length > 0) stopSaver() }
  onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  onFailedAttemptsChanged: if (failedAttempts > 0) shake.restart()
  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // ------------------------------------------------------------ réglages
  readonly property string home: Quickshell.env("HOME")
  property var cfg: ({})
  FileView {
    path: root.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.cfg = JSON.parse(text()) } catch (e) {} }
  }
  // Pochette locale seulement (now-playing.json, écrit par liquid-glass.spotify) :
  // une URL réseau (i.scdn.co) dans Image échoue hors ligne et peut faire planter
  // Quickshell (OpenSSL).
  property var np: ({})
  FileView {
    path: root.home + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.np = JSON.parse(text()) } catch (e) { root.np = ({}) } }
  }
  readonly property string localCover: {
    var u = root.player ? String(root.player.trackArtUrl || "") : ""
    if (u.indexOf("file://") === 0) return u
    if (root.player && root.np.cover && root.np.title === root.player.trackTitle) return "file://" + root.np.cover
    return ""
  }
  readonly property var lcfg: cfg.linux || ({})
  readonly property var kcfg: cfg.lock || ({})
  readonly property string lockVideo: {
    var v = String(Quickshell.env("LG_LOCK_VIDEO") || kcfg.video || "")
    if (v !== "") return v
    return root.video ? root.backgroundPath : ""
  }
  readonly property bool drift: kcfg.drift !== false
  readonly property bool saverOn: kcfg.saver !== false
  readonly property int saverDelay: Math.max(15, Number(kcfg.saver_delay || 60))
  readonly property string style: String(Quickshell.env("LG_LOCK_STYLE") || lcfg.style || "blanc")
  readonly property string vtone: tone("violet_tone", "nuit")
  function tone(key, def) { return String(Quickshell.env("LG_LOCK_TONE") || lcfg[key] || def) }
  readonly property string userName: {
    var u = String(Quickshell.env("USER") || "")
    return u
  }

  // Palettes : pour chaque style, une version sombre et une claire.
  //   a/b : les deux tons des chiffres ; ink : texte ; pill : pastilles ;
  //   acc/accInk : bouton valider ; veil : voile sur le fond.
  readonly property var pals: ({
    violet: {
      dark:  { a: "#ece4ff", b: "#b79ce8", ink: "#ece4ff", sub: "#b6a8d8", pill: Qt.rgba(0.32, 0.24, 0.55, 0.55), acc: "#c9b0ff", accInk: "#2a1858", veil: Qt.rgba(0.08, 0.04, 0.16, 0.10), danger: "#ff7a9a" },
      light: { a: "#2c1b4d", b: "#8a63c9", ink: "#2c1b4d", sub: "#6d5a91", pill: Qt.rgba(1, 1, 1, 0.72), acc: "#3b2463", accInk: "#f4eeff", veil: Qt.rgba(0.94, 0.90, 0.99, 0.62), danger: "#d64b6a" } },
    rose: {
      dark:  { a: "#ffe4ee", b: "#e58fb2", ink: "#ffe4ee", sub: "#d9a9bd", pill: Qt.rgba(0.45, 0.18, 0.32, 0.55), acc: "#f4b3cc", accInk: "#4a1a2c", veil: Qt.rgba(0.12, 0.03, 0.08, 0.12), danger: "#ff7a9a" },
      light: { a: "#4a2533", b: "#c06a8c", ink: "#4a2533", sub: "#8c5c6e", pill: Qt.rgba(1, 1, 1, 0.72), acc: "#8a3e5c", accInk: "#fff3f7", veil: Qt.rgba(0.99, 0.93, 0.95, 0.6), danger: "#d6365a" } },
    crepuscule: {
      dark:  { a: "#f6e9f2", b: "#ffb38a", ink: "#f6e9f2", sub: "#c7aec4", pill: Qt.rgba(0.27, 0.19, 0.31, 0.55), acc: "#ffb38a", accInk: "#0f0a1a", veil: Qt.rgba(0.06, 0.04, 0.10, 0.12), danger: "#ff98a6" },
      light: { a: "#0f0a1a", b: "#bf8668", ink: "#0f0a1a", sub: "#6d606c", pill: Qt.rgba(1.00, 1.00, 1.00, 0.72), acc: "#2c1f44", accInk: "#ffffff", veil: Qt.rgba(0.98, 0.96, 0.97, 0.6), danger: "#c0364e" } },
    lavande: {
      dark:  { a: "#faf9fd", b: "#a39ac8", ink: "#faf9fd", sub: "#a09bb8", pill: Qt.rgba(0.18, 0.16, 0.25, 0.55), acc: "#a39ac8", accInk: "#1a1528", veil: Qt.rgba(0.10, 0.08, 0.16, 0.12), danger: "#ff7a8a" },
      light: { a: "#2e2840", b: "#7b6fb0", ink: "#2e2840", sub: "#6a6383", pill: Qt.rgba(1.00, 1.00, 1.00, 0.72), acc: "#3d3554", accInk: "#faf9fd", veil: Qt.rgba(0.95, 0.95, 0.97, 0.6), danger: "#c0445e" } },
    prune: {
      dark:  { a: "#f4e2ee", b: "#e88ab8", ink: "#f4e2ee", sub: "#c2a0b6", pill: Qt.rgba(0.29, 0.12, 0.24, 0.55), acc: "#e88ab8", accInk: "#0e060c", veil: Qt.rgba(0.05, 0.02, 0.05, 0.12), danger: "#ff8fa2" },
      light: { a: "#0e060c", b: "#ae688a", ink: "#0e060c", sub: "#6b5864", pill: Qt.rgba(1.00, 1.00, 1.00, 0.72), acc: "#2a1426", accInk: "#ffffff", veil: Qt.rgba(0.98, 0.94, 0.96, 0.6), danger: "#c0364e" } },
    ete: {
      dark:  { a: "#fffaf6", b: "#eb919a", ink: "#fffaf6", sub: "#c08f9c", pill: Qt.rgba(0.25, 0.13, 0.23, 0.55), acc: "#eb919a", accInk: "#2a1024", veil: Qt.rgba(0.16, 0.06, 0.14, 0.12), danger: "#ff7a8a" },
      light: { a: "#40213a", b: "#e2626f", ink: "#40213a", sub: "#85566e", pill: Qt.rgba(1.00, 1.00, 1.00, 0.72), acc: "#e2626f", accInk: "#fffaf6", veil: Qt.rgba(1.00, 0.96, 0.93, 0.6), danger: "#d23a52" } },
    automne: {
      dark:  { a: "#f6e8de", b: "#f0915a", ink: "#f6e8de", sub: "#c8a796", pill: Qt.rgba(0.29, 0.16, 0.15, 0.55), acc: "#f0915a", accInk: "#10090b", veil: Qt.rgba(0.06, 0.04, 0.04, 0.12), danger: "#ff8a7a" },
      light: { a: "#10090b", b: "#b46d44", ink: "#10090b", sub: "#6e5c52", pill: Qt.rgba(1.00, 1.00, 1.00, 0.72), acc: "#2d1d22", accInk: "#ffffff", veil: Qt.rgba(0.98, 0.96, 0.93, 0.6), danger: "#c0364e" } },
    hiver: {
      dark:  { a: "#fafcff", b: "#8fa5de", ink: "#fafcff", sub: "#98a5c2", pill: Qt.rgba(0.12, 0.16, 0.27, 0.55), acc: "#8fa5de", accInk: "#111a30", veil: Qt.rgba(0.07, 0.10, 0.19, 0.12), danger: "#ff7a8a" },
      light: { a: "#1f2a44", b: "#5f7fd0", ink: "#1f2a44", sub: "#5a6788", pill: Qt.rgba(1.00, 1.00, 1.00, 0.72), acc: "#2c3a5e", accInk: "#fafcff", veil: Qt.rgba(0.95, 0.96, 0.98, 0.6), danger: "#c43c5a" } },
    printemps: {
      dark:  { a: "#fdfcf8", b: "#e094ae", ink: "#fdfcf8", sub: "#9db2a2", pill: Qt.rgba(0.15, 0.21, 0.16, 0.55), acc: "#e094ae", accInk: "#14211a", veil: Qt.rgba(0.08, 0.13, 0.10, 0.12), danger: "#ff7a8a" },
      light: { a: "#26352a", b: "#d2668c", ink: "#26352a", sub: "#5f7364", pill: Qt.rgba(1.00, 1.00, 1.00, 0.72), acc: "#d2668c", accInk: "#fdfcf8", veil: Qt.rgba(0.97, 0.96, 0.94, 0.6), danger: "#cc3d5e" } },
    mono: {
      dark:  { a: "#f2f2f2", b: "#8c8c8c", ink: "#ededed", sub: "#9a9a9a", pill: Qt.rgba(0.04, 0.04, 0.04, 0.6), acc: "#f2f2f2", accInk: "#0a0a0a", veil: Qt.rgba(0, 0, 0, 0.25), danger: "#ff6b6b" },
      light: { a: "#141414", b: "#9a9a9a", ink: "#141414", sub: "#6e6e6e", pill: Qt.rgba(1, 1, 1, 0.8), acc: "#141414", accInk: "#fafafa", veil: Qt.rgba(0.97, 0.97, 0.97, 0.66), danger: "#c0392b" } },
    jouet: {
      dark:  { a: "#ffd23f", b: "#ff5fa2", ink: "#fff8ee", sub: "#d8ccff", pill: Qt.rgba(0.1, 0.06, 0.19, 0.7), acc: "#ff5fa2", accInk: "#1b1030", veil: Qt.rgba(0.1, 0.06, 0.19, 0.25), danger: "#ff6b6b" },
      light: { a: "#1b1030", b: "#ff5fa2", ink: "#1b1030", sub: "#5b4a7a", pill: Qt.rgba(1, 0.99, 0.97, 0.85), acc: "#ffd23f", accInk: "#1b1030", veil: Qt.rgba(0.91, 0.88, 1, 0.5), danger: "#ff3b3b" } },
    expressive: {
      dark:  { a: "#e2e2e9", b: "#adc6ff", ink: "#e2e2e9", sub: "#c4c6d0", pill: Qt.rgba(0.07, 0.08, 0.1, 0.6), acc: "#adc6ff", accInk: "#102f60", veil: Qt.rgba(0, 0, 0, 0.15), danger: "#ffb4ab" },
      light: { a: "#1a1c20", b: "#3f5f99", ink: "#1a1c20", sub: "#44474f", pill: Qt.rgba(1, 1, 1, 0.75), acc: "#3f5f99", accInk: "#ffffff", veil: Qt.rgba(0.97, 0.97, 1, 0.6), danger: "#ba1a1a" } },
    ile: {
      dark:  { a: "#c9c2cc", b: "#8a8490", ink: "#d8d2da", sub: "#8a8490", pill: Qt.rgba(0.07, 0.06, 0.08, 0.85), acc: "#c9c2cc", accInk: "#17151b", veil: Qt.rgba(0.09, 0.08, 0.11, 0.25), danger: "#e8857c" },
      light: { a: "#c9c2cc", b: "#8a8490", ink: "#d8d2da", sub: "#8a8490", pill: Qt.rgba(0.07, 0.06, 0.08, 0.85), acc: "#c9c2cc", accInk: "#17151b", veil: Qt.rgba(0.09, 0.08, 0.11, 0.25), danger: "#e8857c" } }
  })
  readonly property bool ile: style === "ile"
  readonly property var palSet: ile ? pals.ile : style === "violet" ? (vtone === "rose" ? pals.rose : (pals[vtone] || pals.violet))
                              : style === "jouet" ? pals.jouet
                              : style === "expressive" ? pals.expressive : pals.mono
  readonly property bool defaultLight: (style === "violet" && ["nuit", "minuit", "crepuscule", "prune", "automne"].indexOf(vtone) < 0) || style === "blanc" || style === "jouet"
  property bool light: defaultLight
  onDefaultLightChanged: light = defaultLight

  // Bascule clair/sombre : la nouvelle ambiance s'ouvre en cercle depuis le bouton.
  property bool revealing: false
  property real revealR: 0
  property real revealX: 0
  property real revealY: 0
  function toggleLight(cx, cy) {
    if (revealing) return
    revealX = cx; revealY = cy; revealR = 0
    revealing = true
    revealAnim.to = Math.sqrt(Math.pow(Math.max(cx, width - cx), 2) + Math.pow(Math.max(cy, height - cy), 2)) + 10
    revealAnim.restart()
  }
  NumberAnimation {
    id: revealAnim
    target: root; property: "revealR"; from: 0; duration: 720; easing.type: Easing.InOutCubic
    onFinished: { root.light = !root.light; root.revealing = false; root.revealR = 0 }
  }

  // ------------------------------------------------------------ heure, musique
  property date now: new Date()
  Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }
  readonly property string hh: Qt.formatTime(now, "HH")
  readonly property string mm: Qt.formatTime(now, "mm")
  readonly property string dateText: {
    var s = now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM")
    return s.charAt(0).toUpperCase() + s.slice(1)
  }
  readonly property var player: {
    var list = Mpris.players.values, best = null
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p || !(p.trackTitle || "")) continue
      if (p.isPlaying) return p
      if (!best) best = p
    }
    return best
  }
  readonly property bool hasTrack: !!player && (player.trackTitle || "") !== ""
  // Paroles synchronisées (cache now-playing.json du lecteur), pour les écrans qui les montrent.
  readonly property var lyricLines: hasTrack && np.title === player.trackTitle && Array.isArray(np.lyrics) ? np.lyrics : []
  property int lineIndex: -1
  readonly property string lyricNow: lineIndex >= 0 && lineIndex < lyricLines.length ? String(lyricLines[lineIndex].text || lyricLines[lineIndex].l || "") : ""
  Timer {
    interval: 250; repeat: true
    running: root.lyricLines.length > 0 && root.loadBackground
    onTriggered: {
      var pl = root.player
      if (!pl) return
      if (pl.positionSupported) pl.positionChanged()
      var t = (pl.position || 0) + 0.25, lines = root.lyricLines, i = -1
      while (i + 1 < lines.length && lines[i + 1].t <= t) i++
      if (i !== root.lineIndex) root.lineIndex = i
    }
  }

  // Géométrie partagée par les deux scènes (et le vrai champ de saisie).
  readonly property real clockSize: Math.round(Math.min(height * 0.2, 150))
  // Un style peut avoir son propre écran (LockFace<Nom>.qml) : il dessine tout et dit
  // où se trouve son champ (fieldBox) ; le vrai champ de saisie s'y pose.
  readonly property string faceChoice: String(Quickshell.env("LG_LOCK_STYLE") ? "auto" : (kcfg.linux_face || "auto"))
  readonly property string faceStyle: faceChoice === "auto" ? style : faceChoice
  readonly property string faceName: faceChoice === "classic" ? "" : ({ ile: "Ile", ruban: "Ruban", espace: "Espace", cosmos: "Espace", foret: "Foret",
                                        mono: "Mono", sombre: "Sombre", blanc: "Blanc", jouet: "Jouet", windows: "Windows",
                                        lain: "Lain", expressive: "Expressive", hud: "Hud", infini: "Infini" })[faceStyle] || ""
  readonly property var box: face.item && face.item.fieldBox ? face.item.fieldBox : null
  readonly property real fieldW: box ? box.width : Math.min(360, width - 48)
  readonly property real fieldH: box ? box.height : 36
  readonly property real fieldX: box ? box.x : (width - fieldW) / 2
  readonly property real fieldY: box ? box.y : Math.round(height * 0.68)
  readonly property real shakeX: inputField.shakeX
  function accept() { passwordInput.accepted() }
  property bool powerOpen: false

  // ------------------------------------------------------------ fond
  Rectangle { anchors.fill: parent; color: "#120a24" }
  BackgroundMedia {
    id: wallpaper
    anchors.fill: parent
    path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
    version: root.backgroundVersion
    cached: true
    constrainDecode: true
    decodeSize: Qt.size(width, height)
  }
  LockVideo {
    anchors.fill: parent
    path: root.lockVideo
    active: root.lockVideo !== "" && face.status !== Loader.Ready && root.loadBackground
    visible: active
  }

  // Scène de base (interactive), puis la scène de l'autre ambiance dans le
  // cercle qui grandit pendant la bascule.
  Loader {
    id: face
    anchors.fill: parent
    active: root.faceName !== ""
    source: active ? "LockFace" + root.faceName + ".qml" : ""
    onLoaded: item.lock = root
  }
  Scene { anchors.fill: parent; light: root.light; interactive: true; visible: face.status !== Loader.Ready }
  // Menu d'alimentation des écrans personnalisés (ouvert par leur bouton).
  Rectangle {
    visible: face.status === Loader.Ready && root.powerOpen
    anchors.right: parent.right; anchors.bottom: parent.bottom
    anchors.rightMargin: 16; anchors.bottomMargin: 56
    width: 170; height: facePower.implicitHeight + 12; radius: 12
    color: Qt.rgba(0.08, 0.08, 0.09, 0.92)
    Column {
      id: facePower
      anchors.centerIn: parent; width: parent.width - 12; spacing: 2
      Repeater {
        model: [["bedtime", T.t("Veille"), ["systemctl", "suspend"]],
                ["restart_alt", T.t("Redémarrer"), ["systemctl", "reboot"]],
                ["power_settings_new", T.t("Éteindre"), ["systemctl", "poweroff"]]]
        delegate: Rectangle {
          required property var modelData
          width: parent.width; height: 32; radius: 8
          color: fpm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
          Row {
            x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
            Icon { icon: modelData[0]; size: 16; color: "#eeeeee"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: modelData[1]; color: "#eeeeee"; font.family: "Google Sans Flex"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea { id: fpm; anchors.fill: parent; hoverEnabled: true; onClicked: { root.powerOpen = false; Quickshell.execDetached(modelData[2]) } }
        }
      }
    }
  }
  ClippingRectangle {
    visible: root.revealing && face.status !== Loader.Ready
    x: root.revealX - root.revealR
    y: root.revealY - root.revealR
    width: root.revealR * 2
    height: width
    radius: root.revealR
    color: "transparent"
    Item {
      x: -parent.x; y: -parent.y
      width: root.width; height: root.height
      ShaderEffectSource { anchors.fill: parent; sourceItem: wallpaper; live: false; visible: root.revealing }
      Scene { anchors.fill: parent; light: !root.light; interactive: false }
    }
  }

  // Le vrai champ de saisie : invisible, posé sur le champ dessiné.
  Item {
    id: inputField
    x: root.fieldX
    y: root.fieldY
    width: root.fieldW
    height: root.fieldH
    property real shakeX: 0
    transform: Translate { x: inputField.shakeX }
    SequentialAnimation {
      id: shake
      NumberAnimation { target: inputField; property: "shakeX"; to: -14; duration: 50 }
      NumberAnimation { target: inputField; property: "shakeX"; to: 12; duration: 60 }
      NumberAnimation { target: inputField; property: "shakeX"; to: -8; duration: 60 }
      NumberAnimation { target: inputField; property: "shakeX"; to: 5; duration: 60 }
      NumberAnimation { target: inputField; property: "shakeX"; to: 0; duration: 60 }
    }
    TextInput {
      id: passwordInput
      anchors.fill: parent
      anchors.leftMargin: 44
      anchors.rightMargin: 44
      opacity: 0
      activeFocusOnPress: true
      enabled: root.inputEnabled && !root.authenticatingPassword
      readOnly: root.authenticatingPassword
      echoMode: TextInput.Password
      passwordMaskDelay: 0
      cursorVisible: false
      onTextChanged: {
        if (!root.syncingPasswordText) root.passwordTextEdited(text)
        if (text.length > 0) root.wakeRequested()
        if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
      }
      onAccepted: {
        var submitted = root.passwordText
        root.passwordTextEdited("")
        if (submitted.length > 0) root.submitPassword(submitted)
      }
      Keys.onPressed: function(event) {
        root.wakeRequested()
        if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) { event.accepted = true; return }
        if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
          root.passwordTextEdited("")
          root.powerOpen = false
          event.accepted = true
        }
      }
    }
  }

  // ============================================================ une scène
  component Icon: Text {
    property string icon: ""
    property int size: 18
    text: icon
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.variableAxes: ({ "FILL": 1, "wght": 500 })
    renderType: Text.NativeRendering
  }

  // Chiffre de l'horloge : petit rebond quand il change.
  component Digit: Text {
    id: dg
    property real s: 1
    font.family: "Google Sans Flex"
    font.pixelSize: root.clockSize
    font.variableAxes: ({ "wght": 1000, "ROND": 100, "opsz": 144 })
    scale: s
    onTextChanged: { s = 0.82; bounce.restart() }
    NumberAnimation { id: bounce; target: dg; property: "s"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    Behavior on color { ColorAnimation { duration: 300 } }
  }

  component Pill: Rectangle {
    property alias text: pillText.text
    property string icon: ""
    property var p: null
    height: 30
    width: pillRow.implicitWidth + 24
    radius: 9
    color: p ? p.pill : "transparent"
    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: 7
      Icon { visible: icon !== ""; icon: parent.parent.icon; size: 16; color: p ? p.b : "white"; anchors.verticalCenter: parent.verticalCenter }
      Text {
        id: pillText
        anchors.verticalCenter: parent.verticalCenter
        font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.Medium
        color: p ? p.ink : "white"
      }
    }
  }

  component Scene: Item {
    id: sc
    property bool light: false
    property bool interactive: false
    readonly property var p: light ? root.palSet.light : root.palSet.dark

    Rectangle { anchors.fill: parent; color: sc.p.veil }

    // ---- horloge empilée
    Column {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(root.height * 0.12)
      spacing: -Math.round(root.clockSize * 0.5)
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Math.round(root.clockSize * 0.02)
        Digit { text: root.hh.charAt(0); color: sc.p.a }
        Digit { text: root.hh.charAt(1); color: sc.p.b }
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Math.round(root.clockSize * 0.02)
        Digit { text: root.mm.charAt(0); color: sc.p.b }
        Digit { text: root.mm.charAt(1); color: sc.p.a }
      }
    }
    Pill {
      p: sc.p
      anchors.horizontalCenter: parent.horizontalCenter
      y: clock.y + clock.height - Math.round(root.clockSize * 0.12)
      text: root.dateText
    }

    // ---- champ du mot de passe
    Rectangle {
      id: field
      x: root.fieldX + inputField.shakeX
      y: root.fieldY
      width: root.fieldW
      height: root.fieldH
      radius: 11
      color: sc.p.pill
      border.width: root.errorState ? 1.5 : 0
      border.color: sc.p.danger

      Rectangle {
        x: 5; anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26; radius: 8
        color: Qt.rgba(sc.p.b.r, sc.p.b.g, sc.p.b.b, 0.28)
        Icon {
          anchors.centerIn: parent
          icon: root.fingerprintConfigured ? "fingerprint" : (root.authenticatingPassword ? "hourglass_top" : "lock")
          size: 16
          color: root.fingerprintUnavailable || root.errorState ? sc.p.danger : sc.p.ink
        }
      }

      // Un carré par caractère, qui « pousse » à son apparition.
      Row {
        anchors.centerIn: parent
        spacing: 5
        visible: root.passwordText.length > 0
        opacity: root.authenticatingPassword ? 0.5 : 1
        SequentialAnimation on opacity {
          running: root.authenticatingPassword; loops: Animation.Infinite
          NumberAnimation { to: 0.3; duration: 420 }
          NumberAnimation { to: 0.9; duration: 420 }
        }
        Repeater {
          model: Math.min(22, root.passwordText.length)
          delegate: Rectangle {
            width: 13; height: 13; radius: 3.5
            color: sc.p.ink
            scale: 0.3
            Component.onCompleted: scale = 1
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
          }
        }
      }
      Text {
        anchors.centerIn: parent
        visible: root.passwordText.length === 0
        text: root.authenticatingPassword ? T.t("Vérification…")
            : root.errorState ? root.failureMessage
            : (root.fingerprintConfigured ? T.t("Empreinte ou mot de passe") : T.t("Mot de passe"))
        font.family: "Google Sans Flex"; font.pixelSize: 13
        color: root.errorState ? sc.p.danger : sc.p.sub
      }

      Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26; radius: 8
        color: sc.p.acc
        scale: goMouse.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        Icon { anchors.centerIn: parent; icon: "chevron_right"; size: 18; color: sc.p.accInk }
        MouseArea {
          id: goMouse
          anchors.fill: parent
          enabled: sc.interactive
          cursorShape: Qt.PointingHandCursor
          onClicked: passwordInput.accepted()
        }
      }
      MouseArea {
        anchors.fill: parent; anchors.leftMargin: 36; anchors.rightMargin: 36
        enabled: sc.interactive
        cursorShape: Qt.IBeamCursor
        onClicked: root.forcePasswordFocus()
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.fieldY + root.fieldH + 14
      spacing: 8
      Pill { p: sc.p; icon: "person"; text: root.userName }
      Pill { p: sc.p; icon: "settings"; text: "Hyprland" }
    }

    // ---- morceau en cours
    Rectangle {
      visible: root.hasTrack
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 26
      height: 46
      width: Math.min(420, musicRow.implicitWidth + 16)
      radius: 13
      color: sc.p.pill
      Row {
        id: musicRow
        anchors.verticalCenter: parent.verticalCenter
        x: 7
        spacing: 10
        ClippingRectangle {
          width: 32; height: 32; radius: 8
          anchors.verticalCenter: parent.verticalCenter
          color: Qt.rgba(sc.p.b.r, sc.p.b.g, sc.p.b.b, 0.3)
          Image {
            anchors.fill: parent
            source: root.hasTrack ? root.localCover : ""
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }
        }
        // Petites barres qui dansent pendant la lecture.
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Repeater {
            model: 4
            delegate: Rectangle {
              required property int index
              width: 3; radius: 1.5
              anchors.bottom: parent.bottom
              color: sc.p.b
              height: 5
              SequentialAnimation on height {
                running: root.hasTrack && root.player.isPlaying; loops: Animation.Infinite
                NumberAnimation { to: 8 + (index * 7) % 13; duration: 260 + index * 70; easing.type: Easing.InOutSine }
                NumberAnimation { to: 4; duration: 300 + index * 50; easing.type: Easing.InOutSine }
              }
            }
          }
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(220, Math.max(t1.implicitWidth, t2.implicitWidth))
          Text { id: t1; width: parent.width; elide: Text.ElideRight; text: root.hasTrack ? root.player.trackTitle : ""; font.family: "Google Sans Flex"; font.pixelSize: 12; font.weight: Font.DemiBold; color: sc.p.ink }
          Text { id: t2; width: parent.width; elide: Text.ElideRight; text: root.hasTrack ? (root.player.trackArtist || "") : ""; font.family: "Google Sans Flex"; font.pixelSize: 11; color: sc.p.sub }
        }
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Repeater {
            model: [["skip_previous", 0], [root.hasTrack && root.player.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2]]
            delegate: Rectangle {
              required property var modelData
              width: 28; height: 28; radius: 8
              color: mBtn.containsMouse ? Qt.rgba(sc.p.b.r, sc.p.b.g, sc.p.b.b, 0.25) : "transparent"
              Icon { anchors.centerIn: parent; icon: modelData[0]; size: 20; color: sc.p.ink }
              MouseArea {
                id: mBtn
                anchors.fill: parent
                enabled: sc.interactive
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!root.player) return
                  if (modelData[1] === 0) root.player.previous()
                  else if (modelData[1] === 1) root.player.togglePlaying()
                  else root.player.next()
                  root.forcePasswordFocus()
                }
              }
            }
          }
        }
      }
    }

    // ---- clair/sombre et alimentation
    Row {
      id: corner
      anchors.right: parent.right; anchors.bottom: parent.bottom
      anchors.margins: 18
      spacing: 8
      Rectangle {
        id: themeBtn
        width: 32; height: 32; radius: 9
        color: sc.p.pill
        Icon { anchors.centerIn: parent; icon: sc.light ? "dark_mode" : "light_mode"; size: 17; color: sc.p.ink }
        MouseArea {
          anchors.fill: parent
          enabled: sc.interactive
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var pt = themeBtn.mapToItem(root, themeBtn.width / 2, themeBtn.height / 2)
            root.toggleLight(pt.x, pt.y)
            root.forcePasswordFocus()
          }
        }
      }
      Rectangle {
        width: 32; height: 32; radius: 9
        color: root.powerOpen ? sc.p.danger : sc.p.pill
        Behavior on color { ColorAnimation { duration: 160 } }
        Icon { anchors.centerIn: parent; icon: root.powerOpen ? "close" : "power_settings_new"; size: 17; color: root.powerOpen ? "white" : sc.p.danger }
        MouseArea {
          anchors.fill: parent
          enabled: sc.interactive
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.powerOpen = !root.powerOpen; root.forcePasswordFocus() }
        }
      }
    }
    Rectangle {
      id: powerMenu
      anchors.right: corner.right
      anchors.bottom: corner.top
      anchors.bottomMargin: 10
      width: 168
      height: powerCol.implicitHeight + 12
      radius: 13
      color: sc.p.pill
      opacity: root.powerOpen ? 1 : 0
      visible: opacity > 0
      scale: root.powerOpen ? 1 : 0.92
      transformOrigin: Item.BottomRight
      Behavior on opacity { NumberAnimation { duration: 180 } }
      Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
      Column {
        id: powerCol
        anchors.centerIn: parent
        width: parent.width - 12
        spacing: 2
        Repeater {
          model: [["bedtime", T.t("Veille"), ["systemctl", "suspend"]],
                  ["restart_alt", T.t("Redémarrer"), ["systemctl", "reboot"]],
                  ["power_settings_new", T.t("Éteindre"), ["systemctl", "poweroff"]]]
          delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property bool danger: index === 2
            width: parent.width; height: 34; radius: 9
            color: pm.containsMouse ? (danger ? sc.p.danger : sc.p.acc) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            Row {
              anchors.verticalCenter: parent.verticalCenter
              x: 12; spacing: 10
              Icon { icon: modelData[0]; size: 17; anchors.verticalCenter: parent.verticalCenter
                     color: pm.containsMouse ? (danger ? "white" : sc.p.accInk) : (danger ? sc.p.danger : sc.p.ink) }
              Text { text: modelData[1]; anchors.verticalCenter: parent.verticalCenter
                     font.family: "Google Sans Flex"; font.pixelSize: 13; font.weight: Font.Medium
                     color: pm.containsMouse ? (danger ? "white" : sc.p.accInk) : (danger ? sc.p.danger : sc.p.ink) }
            }
            MouseArea {
              id: pm
              anchors.fill: parent
              enabled: sc.interactive && root.powerOpen
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.powerOpen = false; Quickshell.execDetached(modelData[2]) }
            }
          }
        }
      }
    }
  }

  // Écran de veille feu ASCII : après [lock] saver_delay secondes sans rien toucher.
  property bool saving: String(Quickshell.env("LG_LOCK_SAVER") || "") !== ""
  Timer { id: saverTimer; interval: root.saverDelay * 1000; running: root.saverOn && !root.saving && root.passwordText.length === 0; onTriggered: root.saving = true }
  function stopSaver() { root.saving = false; saverTimer.restart() }
  onWakeRequested: stopSaver()
  HoverHandler { id: saverHover }
  readonly property point saverPos: saverHover.point.position
  onSaverPosChanged: if (saving) stopSaver(); else saverTimer.restart()
  FireSaver {
    anchors.fill: parent
    shown: root.saving
    z: 100
    MouseArea { anchors.fill: parent; enabled: root.saving; hoverEnabled: true; onPositionChanged: root.stopSaver(); onClicked: { root.stopSaver(); root.forcePasswordFocus() } }
  }
}
