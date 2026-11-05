import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// ============================================================================
// Liquid Glass — vue de l'écran de verrouillage façon macOS.
// Clone visuel de omarchy.lock/LockView.qml : la saisie et l'authentification
// (propriétés, signaux, TextInput et ses gestionnaires, empreinte) sont celles
// d'Omarchy, inchangées ; Service.qml (PAM) n'est pas modifié.
// Ajouts purement visuels : date + grande horloge, avatar (~/.face ou initiale),
// champ « pilule » en verre, et pendant la lecture : pochette floutée en fond
// + mini-lecteur (lu via MPRIS et ~/.cache/liquid-glass/now-playing.json).
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

  readonly property string uiFont: "Inter"
  readonly property string placeholderText: "Saisir le mot de passe"
  readonly property int fieldWidth: 250
  readonly property int fieldHeight: 36
  readonly property int fieldFontSize: 14
  readonly property int passwordDotFontSize: 15
  readonly property int passwordDotLetterSpacing: 3
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 8) : 0
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0

  // A video wallpaper shows its still poster: nothing plays behind the lock.
  readonly property bool video: Util.isVideoPath(root.backgroundPath)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function restorePasswordFocus() {
    if (inputEnabled && passwordInput.enabled && !passwordInput.activeFocus) forcePasswordFocus()
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  // Mot de passe refusé : le champ « secoue la tête », comme sur macOS.
  onFailedAttemptsChanged: if (failedAttempts > 0) shake.restart()

  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  // ------------------------------------------------------------ musique
  readonly property var player: {
    var ps = Mpris.players ? Mpris.players.values : []
    var spotify = null, playing = null
    for (var i = 0; i < ps.length; i++) {
      var id = String((ps[i].identity || "") + " " + (ps[i].desktopEntry || "")).toLowerCase()
      if (!spotify && id.indexOf("spotify") !== -1) spotify = ps[i]
      if (!playing && ps[i].isPlaying) playing = ps[i]
    }
    return playing || spotify
  }
  readonly property bool musicActive: !!player && (player.trackTitle || "") !== ""
  property var nowPlaying: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/now-playing.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.nowPlaying = JSON.parse(text()) } catch (e) { root.nowPlaying = ({}) } }
  }
  readonly property string coverSource: {
    if (!musicActive) return ""
    if (nowPlaying.cover && nowPlaying.title === player.trackTitle) return "file://" + nowPlaying.cover
    var art = String(player.trackArtUrl || "")
    return art.indexOf("file://") === 0 ? art : ""
  }

  // Avatar : ~/.face s'il existe (sinon l'initiale). Test d'existence sans avertissement.
  property bool hasFace: false
  Process {
    command: ["test", "-f", Quickshell.env("HOME") + "/.face"]
    running: true
    onExited: function(code) { root.hasFace = code === 0 }
  }

  // ------------------------------------------------------------ fond
  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background

    BackgroundMedia {
      id: wallpaper
      objectName: "lockWallpaper"
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    // Pochette floutée par-dessus le fond pendant la lecture.
    Image {
      id: coverBg
      anchors.fill: parent
      source: root.loadBackground ? root.coverSource : ""
      sourceSize: Qt.size(512, 512)
      fillMode: Image.PreserveAspectCrop
      visible: false
      asynchronous: true
    }
    MultiEffect {
      anchors.fill: parent
      source: coverBg
      autoPaddingEnabled: false
      blurEnabled: true
      blur: 1.0
      blurMax: 96
      saturation: 0.25
      brightness: -0.12
      opacity: coverBg.status === Image.Ready ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 600 } }
    }
    // Léger voile pour que le texte blanc reste lisible sur les fonds clairs.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.18) }
        GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.04) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.22) }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // ---------------------------------------------------------- horloge
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
      id: clockColumn
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.09)
      spacing: -4

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: {
          var s = Qt.locale("fr_FR").toString(clock.date, "dddd d MMMM")
          return s.charAt(0).toUpperCase() + s.slice(1)
        }
        font.family: root.uiFont; font.pixelSize: Math.round(root.height * 0.028); font.weight: Font.DemiBold
        color: "white"; opacity: 0.88
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowColor: "#40000000"; shadowVerticalOffset: 1 }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.formatTime(clock.date, "HH:mm")
        font.family: root.uiFont; font.pixelSize: Math.round(root.height * 0.15); font.weight: Font.Bold
        font.letterSpacing: -2
        font.features: { "tnum": 1 }
        color: "white"; opacity: 0.92
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.8; shadowColor: "#38000000"; shadowVerticalOffset: 2 }
      }
    }

    // ---------------------------------------------------------- lecture en cours
    Rectangle {
      id: nowCard
      visible: root.musicActive
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: clockColumn.bottom
      anchors.topMargin: Math.round(root.height * 0.03)
      width: 340; height: 76
      radius: 18
      color: Qt.rgba(1, 1, 1, 0.16)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.28)

      Item {
        id: art
        x: 10; anchors.verticalCenter: parent.verticalCenter
        width: 56; height: 56
        Image { id: artImg; anchors.fill: parent; source: root.coverSource; sourceSize: Qt.size(112, 112); fillMode: Image.PreserveAspectCrop; visible: false }
        Rectangle { id: artMask; anchors.fill: parent; radius: 10; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: artImg; maskEnabled: true; maskSource: artMask; visible: artImg.status === Image.Ready }
        Rectangle { anchors.fill: parent; radius: 10; color: Qt.rgba(1, 1, 1, 0.2); visible: artImg.status !== Image.Ready }
      }
      Column {
        anchors.left: art.right; anchors.leftMargin: 12
        anchors.right: controls.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text { width: parent.width; textFormat: Text.PlainText; text: root.player ? root.player.trackTitle || "" : ""; elide: Text.ElideRight; font.family: root.uiFont; font.pixelSize: 14; font.weight: Font.DemiBold; color: "white" }
        Text { width: parent.width; textFormat: Text.PlainText; text: root.player ? root.player.trackArtist || "" : ""; elide: Text.ElideRight; font.family: root.uiFont; font.pixelSize: 12; color: "white"; opacity: 0.7 }
      }
      Row {
        id: controls
        anchors.right: parent.right; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
          model: [
            [0xF04AE, function() { root.player.previous() }],
            [-1, function() { root.player.togglePlaying() }],
            [0xF04AD, function() { root.player.next() }]
          ]
          delegate: Item {
            required property var modelData
            width: 30; height: 30
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: String.fromCodePoint(modelData[0] === -1 ? (root.player && root.player.isPlaying ? 0xF03E4 : 0xF040A) : modelData[0])
              font.family: Style.font.family; font.pixelSize: modelData[0] === -1 ? 24 : 18
              color: "white"
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.player) modelData[1](); root.forcePasswordFocus() } }
          }
        }
      }
    }

    // ---------------------------------------------------------- utilisateur + mot de passe
    Column {
      id: userColumn
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.round(parent.height * 0.70)
      spacing: 10

      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 64; height: 64
        Image {
          id: face
          anchors.fill: parent
          source: root.hasFace ? "file://" + Quickshell.env("HOME") + "/.face" : ""
          sourceSize: Qt.size(128, 128)
          fillMode: Image.PreserveAspectCrop
          visible: false
          cache: false
        }
        Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: face; maskEnabled: true; maskSource: faceMask; visible: face.status === Image.Ready }
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          visible: face.status !== Image.Ready
          gradient: Gradient {
            GradientStop { position: 0; color: "#9aa7ff" }
            GradientStop { position: 1; color: "#5b6cf0" }
          }
          border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.4)
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: String(Quickshell.env("USER") || "?").charAt(0).toUpperCase()
            font.family: root.uiFont; font.pixelSize: 28; font.weight: Font.DemiBold
            color: "white"
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: { var u = String(Quickshell.env("USER") || ""); return u.charAt(0).toUpperCase() + u.slice(1) }
        font.family: root.uiFont; font.pixelSize: 15; font.weight: Font.DemiBold
        color: "white"
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.5; shadowColor: "#40000000"; shadowVerticalOffset: 1 }
      }

      Item {
        id: fieldSlot
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fieldWidth; height: root.fieldHeight

        Rectangle {
          id: inputField
          // Mêmes noms que la BorderSurface d'origine, utilisés par les marges du champ.
          readonly property int borderTop: 1
          readonly property int borderRight: 1
          readonly property int borderBottom: 1
          readonly property int borderLeft: 1
          width: parent.width; height: parent.height
          radius: height / 2
          color: Qt.rgba(1, 1, 1, passwordInput.activeFocus ? 0.24 : 0.18)
          border.width: 1
          border.color: root.errorState ? Qt.rgba(1, 0.35, 0.33, 0.85) : Qt.rgba(1, 1, 1, 0.38)
          clip: true
          Behavior on color { ColorAnimation { duration: 150 } }

          SequentialAnimation {
            id: shake
            loops: 1
            NumberAnimation { target: inputField; property: "x"; to: -14; duration: 50 }
            NumberAnimation { target: inputField; property: "x"; to: 12; duration: 60 }
            NumberAnimation { target: inputField; property: "x"; to: -8; duration: 60 }
            NumberAnimation { target: inputField; property: "x"; to: 5; duration: 60 }
            NumberAnimation { target: inputField; property: "x"; to: 0; duration: 60 }
          }

          TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.topMargin: inputField.borderTop
            anchors.rightMargin: inputField.borderRight + 16 + root.fingerprintReserve
            anchors.bottomMargin: inputField.borderBottom
            anchors.leftMargin: inputField.borderLeft + 16 + root.fingerprintReserve
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            activeFocusOnPress: true
            clip: true
            enabled: root.inputEnabled && !root.authenticatingPassword
            readOnly: root.authenticatingPassword
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            color: "white"
            selectionColor: Qt.rgba(1, 1, 1, 0.35)
            selectedTextColor: "white"
            font.family: Style.font.family
            font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
            font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
            cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
            cursorDelegate: Rectangle {
              width: 2
              color: "white"
              visible: passwordInput.cursorVisible
            }

            onTextChanged: {
              if (!root.syncingPasswordText) root.passwordTextEdited(text)
              if (text.length > 0) {
                root.wakeRequested()
              }
              if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
            }

            onAccepted: {
              var submitted = root.passwordText
              root.passwordTextEdited("")
              if (submitted.length > 0) root.submitPassword(submitted)
            }

            Keys.onPressed: function(event) {
              root.wakeRequested()
              if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                root.passwordTextEdited("")
                event.accepted = true
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: passwordInput
            text: root.authenticatingPassword ? "Vérification…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
            visible: passwordInput.text.length === 0
            color: root.failureMessage.length > 0 && !root.authenticatingPassword ? "#ffd2d0" : Qt.rgba(1, 1, 1, 0.7)
            font.family: root.uiFont
            font.pixelSize: root.fieldFontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          Text {
            id: fingerprintIcon
            objectName: "fingerprintIndicator"
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.rightMargin: inputField.borderRight + 12
            anchors.verticalCenter: parent.verticalCenter
            visible: root.fingerprintConfigured
            text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
            color: root.fingerprintUnavailable ? "#ffd2d0" : Qt.rgba(1, 1, 1, 0.7)
            font.family: Style.font.family
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }
      }

      Text {
        objectName: "fingerprintUnavailableNotice"
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        visible: root.fingerprintConfigured && root.fingerprintUnavailable
        text: Commons.I18n.t("lock.fingerprintUnavailable")
        color: "#ffd2d0"
        font.family: root.uiFont
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        visible: root.fingerprintConfigured && !root.fingerprintUnavailable
        text: "Touchez le lecteur d'empreintes ou saisissez le mot de passe"
        font.family: root.uiFont; font.pixelSize: 12
        color: "white"; opacity: 0.7
      }
    }
  }
}
