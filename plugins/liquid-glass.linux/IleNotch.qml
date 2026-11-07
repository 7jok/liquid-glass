import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets
import "T.js" as T

// Style Île : l'encoche noire. Fermée, l'heure et la météo. Une notification la fait descendre.
// Un clic l'ouvre sur huit onglets : musique et outils, presse-papiers, texte, étagère, chat,
// notes, météo, contrôles.
PanelWindow {
  id: win
  property var service: null
  readonly property var s: service

  anchors { top: true; left: true; right: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  mask: Region { item: win.open ? catcher : hit }
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "liquid-glass-linux-ile-notch"
  WlrLayershell.keyboardFocus: win.open ? win.s.kbd(false) : WlrKeyboardFocus.None

  readonly property color ink: "#d8d2da"
  readonly property color sub: "#8a8490"
  readonly property color tile: "#1d1b20"
  readonly property color tile2: "#2a272e"
  readonly property string font: s.sansFont
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/liquid-glass"

  property bool open: false
  property string tab: "home"
  property var note: null
  readonly property bool showNote: !!note && !open

  readonly property real bodyW: open ? Math.min(760, width - 40) : (showNote ? 430 : (hover.hovered ? 200 : 180))
  readonly property real bodyH: open ? 396 : (showNote ? 66 : 30)

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

  MouseArea { id: catcher; anchors.fill: parent; onClicked: win.open = false }
  Shortcut { sequence: "Escape"; onActivated: win.open = false }

  // Zone cliquable fermée : le corps de l'encoche et rien d'autre.
  Item { id: hit; x: body.x; y: 0; width: body.width; height: body.height }

  // Épaules concaves, comme une encoche qui sort de l'écran.
  Canvas {
    x: body.x - 12; y: 0; width: 12; height: 12
    onPaint: { var c = getContext("2d"); c.fillStyle = "#000"; c.beginPath(); c.moveTo(0, 0); c.lineTo(12, 0); c.lineTo(12, 12); c.arc(0, 12, 12, 0, -Math.PI / 2, true); c.fill() }
  }
  Canvas {
    x: body.x + body.width; y: 0; width: 12; height: 12
    onPaint: { var c = getContext("2d"); c.fillStyle = "#000"; c.beginPath(); c.moveTo(12, 0); c.lineTo(0, 0); c.lineTo(0, 12); c.arc(12, 12, 12, Math.PI, Math.PI * 1.5, false); c.fill() }
  }

  Rectangle {
    id: body
    x: (win.width - width) / 2
    y: 0
    width: win.bodyW
    height: win.bodyH
    color: "#000000"
    bottomLeftRadius: win.open ? 28 : 16
    bottomRightRadius: win.open ? 28 : 16
    clip: true
    Behavior on width { SpringAnimation { spring: 3.4; damping: 0.34; epsilon: 0.3 } }
    Behavior on height { SpringAnimation { spring: 3.4; damping: 0.34; epsilon: 0.3 } }
    HoverHandler { id: hover }
    MouseArea {
      anchors.fill: parent
      enabled: !win.open
      cursorShape: Qt.PointingHandCursor
      onClicked: { win.note = null; win.open = true }
    }

    // Fermée : météo à droite, heure au centre.
    Row {
      visible: !win.open && !win.showNote
      anchors.centerIn: parent
      spacing: 10
      MIcon { anchors.verticalCenter: parent.verticalCenter; visible: win.s.playing; icon: "graphic_eq"; size: 14; color: win.ink }
      Text { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatTime(win.now, "HH:mm"); color: win.ink; font.family: win.font; font.pixelSize: 12; font.weight: Font.DemiBold }
      MIcon { anchors.verticalCenter: parent.verticalCenter; visible: !!win.s.weather; icon: win.s.weatherIcon; size: 14; color: win.ink }
      Text { anchors.verticalCenter: parent.verticalCenter; visible: !!win.s.weather; text: win.s.weather ? win.s.weather.temp + "°" : ""; color: win.ink; font.family: win.font; font.pixelSize: 12 }
    }

    // Notification
    Row {
      visible: win.showNote
      opacity: visible ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 240 } }
      anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 18 }
      spacing: 12
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 34; height: 34; radius: 17
        color: win.note && win.note.tint ? win.note.tint : "#2d6a4f"
        MIcon { anchors.centerIn: parent; icon: win.note ? win.note.icon : "check"; size: 19; fill: 1; color: "#ffffff" }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 46
        spacing: 2
        Text { width: parent.width; text: win.note ? win.note.title : ""; color: "#ffffff"; font.family: win.font; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; textFormat: Text.PlainText }
        Text { width: parent.width; visible: text !== ""; text: win.note ? win.note.body : ""; color: win.sub; font.family: win.font; font.pixelSize: 11; elide: Text.ElideRight; textFormat: Text.PlainText }
      }
    }

    // Ouverte
    Item {
      anchors.fill: parent
      visible: win.open
      opacity: win.open ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 200 } }

      // Onglets
      Row {
        id: tabs
        x: 18; y: 12; height: 30
        spacing: 4
        Repeater {
          model: [["home", "home", T.t("Accueil")], ["clip", "content_paste", T.t("Presse-papiers")], ["text", "title", T.t("Texte")],
                  ["shelf", "inventory_2", T.t("Étagère")], ["chat", "chat_bubble", "Chat"], ["notes", "edit_note", T.t("Notes")],
                  ["weather", "partly_cloudy_day", T.t("Météo")], ["manage", "tune", T.t("Contrôles")]]
          Rectangle {
            id: tb
            required property var modelData
            readonly property bool on: win.tab === modelData[0]
            width: on ? lbl.implicitWidth + 40 : 32
            height: 30; radius: 15
            color: on ? win.tile2 : "transparent"
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            clip: true
            MIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; icon: tb.modelData[1]; size: 16; color: tb.on ? win.ink : win.sub }
            Text { id: lbl; x: 30; anchors.verticalCenter: parent.verticalCenter; visible: tb.on; text: tb.modelData[2]; color: win.ink; font.family: win.font; font.pixelSize: 12; font.weight: Font.DemiBold }
            TapHandler { onTapped: win.tab = tb.modelData[0] }
          }
        }
      }
      Row {
        anchors { right: parent.right; rightMargin: 20; verticalCenter: tabs.verticalCenter }
        spacing: 12
        Rectangle {
          visible: win.s.batteryPct >= 0
          anchors.verticalCenter: parent.verticalCenter
          width: 42; height: 22; radius: 11; color: win.tile2
          Text { anchors.centerIn: parent; text: win.s.batteryPct; color: win.ink; font.family: win.font; font.pixelSize: 11; font.weight: Font.DemiBold }
        }
        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.netWifi ? "wifi" : "lan"; size: 15; color: win.sub }
        MIcon {
          anchors.verticalCenter: parent.verticalCenter
          icon: "settings"; size: 15; color: win.sub
          TapHandler { onTapped: { win.open = false; win.s.toggleMenu("") } }
        }
      }

      Item {
        id: page
        x: 18; y: 52
        width: parent.width - 36
        height: parent.height - 70

        // ---------- Accueil
        Item {
          anchors.fill: parent
          visible: win.tab === "home"
          Rectangle {
            id: player
            width: parent.width - 224; height: 172; radius: 16; color: win.tile
            ClippingRectangle {
              id: art
              x: 14; y: 14; width: 66; height: 66; radius: 10; color: win.tile2
              Image { anchors.fill: parent; source: win.s.cover; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            }
            Column {
              x: 92; y: 16; width: (parent.width - 110) / 2
              spacing: 3
              Text { width: parent.width; text: win.s.trackTitle || T.t("Aucune musique"); color: win.ink; font.family: win.font; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; textFormat: Text.PlainText }
              Text { width: parent.width; text: win.s.trackArtist; color: win.sub; font.family: win.font; font.pixelSize: 11; elide: Text.ElideRight; textFormat: Text.PlainText }
            }
            Rectangle {
              x: 92; y: 62; width: (parent.width - 110) / 2; height: 3; radius: 2; color: win.tile2
              Rectangle { width: parent.width * win.s.progress; height: 3; radius: 2; color: win.ink }
            }
            Text { x: 92; y: 69; text: win.s.fmtTime(win.s.position); color: win.sub; font.family: win.font; font.pixelSize: 9 }
            Text { x: 92 + (parent.width - 110) / 2 - width; y: 69; text: "-" + win.s.fmtTime(Math.max(0, win.s.length - win.s.position)); color: win.sub; font.family: win.font; font.pixelSize: 9 }
            Row {
              x: 92 + ((parent.width - 110) / 2 - width) / 2; y: 100
              spacing: 18
              MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "skip_previous"; size: 26; fill: 1; color: win.ink; TapHandler { onTapped: if (win.s.player) win.s.player.previous() } }
              Rectangle {
                width: 46; height: 46; radius: 23; color: win.ink
                MIcon { anchors.centerIn: parent; icon: win.s.playing ? "pause" : "play_arrow"; size: 26; fill: 1; color: "#000000" }
                TapHandler { onTapped: win.s.playPause() }
              }
              MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "skip_next"; size: 26; fill: 1; color: win.ink; TapHandler { onTapped: if (win.s.player) win.s.player.next() } }
            }
            // Paroles : la ligne en cours, nette ; la suivante, floue de gris.
            Rectangle { x: parent.width / 2 + 42; y: 14; width: 1; height: parent.height - 28; color: win.tile2 }
            Column {
              x: parent.width / 2 + 54; y: 44; width: parent.width / 2 - 66
              spacing: 8
              Text { width: parent.width; text: win.s.line || (win.s.hasTrack ? "♪" : ""); color: win.ink; font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight; textFormat: Text.PlainText }
              Text {
                width: parent.width
                text: win.s.lineIndex + 1 < win.s.lyrics.length && win.s.lineIndex >= 0 ? String(win.s.lyrics[win.s.lineIndex + 1].text || "") : ""
                color: win.sub; font.family: win.font; font.pixelSize: 12; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText
              }
            }
            Text { anchors { right: parent.right; rightMargin: 12; bottom: parent.bottom; bottomMargin: 8 } text: "LRCLIB"; color: "#5e5864"; font.family: win.font; font.pixelSize: 8 }
          }
          // Volume et sortie
          Rectangle {
            y: 180; width: player.width; height: 40; radius: 12; color: win.tile
            MIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; icon: "volume_up"; size: 16; color: win.sub }
            Rectangle {
              id: volBar
              x: 38; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 218; height: 3; radius: 2; color: win.tile2
              Rectangle { width: parent.width * win.vol; height: 3; radius: 2; color: win.ink }
              MouseArea {
                anchors.fill: parent; anchors.margins: -10
                function apply(mx) { if (win.sink && win.sink.audio) win.sink.audio.volume = Math.max(0, Math.min(1, (mx - 10) / volBar.width)) }
                onPressed: function(e) { apply(e.x) }
                onPositionChanged: function(e) { if (pressed) apply(e.x) }
              }
            }
            Text { x: parent.width - 170; anchors.verticalCenter: parent.verticalCenter; text: Math.round(win.vol * 100); color: win.sub; font.family: win.font; font.pixelSize: 11 }
            Rectangle {
              anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
              width: 138; height: 26; radius: 8; color: win.tile2
              Text {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                text: win.sink ? String(win.sink.description || win.sink.nickname || win.sink.name) : ""
                color: win.ink; font.family: win.font; font.pixelSize: 10; textFormat: Text.PlainText
              }
              TapHandler { onTapped: { win.open = false; win.s.run("omarchy-launch-audio") } }
            }
          }
          // Outils
          Grid {
            x: parent.width - 216; columns: 2; spacing: 8
            Repeater {
              model: [["document_scanner", T.t("Texte de l'écran"), "grim -g \"$(slurp)\" - | tesseract - - 2>/dev/null | wl-copy"],
                      ["qr_code_2", T.t("Code QR"), "f=\"$XDG_RUNTIME_DIR/lg-qr.png\"; wl-paste -n | qrencode -s 10 -o \"$f\" && xdg-open \"$f\""],
                      ["colorize", T.t("Pipette"), "hyprpicker -a"],
                      ["ink_eraser", T.t("Texte brut"), "wl-paste -n -t text/plain | wl-copy"],
                      ["screen_record", T.t("Enregistrer l'écran"), "omarchy-capture-screenrecording"],
                      ["search", T.t("Commande"), "@launcher"]]
              Rectangle {
                id: tool
                required property var modelData
                width: 104; height: 66; radius: 12
                color: toolHover.hovered ? win.tile2 : win.tile
                Row {
                  anchors.centerIn: parent; spacing: 7; width: parent.width - 18
                  MIcon { anchors.verticalCenter: parent.verticalCenter; icon: tool.modelData[0]; size: 17; color: win.ink }
                  Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24; text: tool.modelData[1]; color: win.ink; font.family: win.font; font.pixelSize: 11; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
                }
                HoverHandler { id: toolHover }
                TapHandler {
                  onTapped: {
                    win.open = false
                    if (tool.modelData[2] === "@launcher") win.s.toggleLauncher()
                    else win.s.run("sleep 0.25; " + tool.modelData[2])
                  }
                }
              }
            }
          }
          // Raccourcis déposés
          Rectangle {
            y: 228; width: parent.width; height: parent.height - 228; radius: 14; color: win.tile
            Rectangle {
              x: 10; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40; radius: 10; color: "transparent"; border.color: win.tile2; border.width: 1
              Text { anchors.centerIn: parent; text: "+"; color: win.sub; font.pixelSize: 20 }
            }
            Text {
              x: 62; anchors.verticalCenter: parent.verticalCenter
              visible: win.shelf.length === 0
              text: T.t("Dépose ici des raccourcis, dossiers ou fichiers"); color: win.sub; font.family: win.font; font.pixelSize: 12
            }
            Row {
              x: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 8
              Repeater {
                model: win.shelf.slice(0, 7)
                Rectangle {
                  id: sc
                  required property var modelData
                  width: 84; height: 40; radius: 8; color: win.tile2
                  Text { anchors.fill: parent; anchors.margins: 6; verticalAlignment: Text.AlignVCenter; text: sc.modelData.split("/").pop(); color: win.ink; font.family: win.font; font.pixelSize: 10; elide: Text.ElideMiddle; textFormat: Text.PlainText }
                  TapHandler { onTapped: { win.open = false; Quickshell.execDetached(["xdg-open", sc.modelData]) } }
                }
              }
            }
            DropArea { anchors.fill: parent; onDropped: function(d) { win.addFiles(d.urls) } }
          }
        }

        // ---------- Presse-papiers
        Item {
          anchors.fill: parent
          visible: win.tab === "clip"
          ListView {
            id: clipList
            anchors { fill: parent; bottomMargin: 26 }
            clip: true; spacing: 6
            model: win.clips
            delegate: Rectangle {
              id: cl
              required property var modelData
              required property int index
              width: clipList.width; height: 52; radius: 10
              color: clHover.hovered ? win.tile2 : win.tile
              Rectangle {
                x: 10; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 8; color: win.tile2
                MIcon { anchors.centerIn: parent; icon: String(cl.modelData.type || "").indexOf("image") >= 0 ? "image" : "notes"; size: 16; color: win.ink }
              }
              Column {
                x: 52; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 66
                Text { width: parent.width; text: String(cl.modelData.text || T.t("Image")).replace(/\s+/g, " "); color: win.ink; font.family: win.font; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; textFormat: Text.PlainText }
                Text { width: parent.width; text: String(cl.modelData.type || ""); color: win.sub; font.family: win.font; font.pixelSize: 10; elide: Text.ElideRight; textFormat: Text.PlainText }
              }
              HoverHandler { id: clHover }
              TapHandler { onTapped: { if (cl.modelData.text) Quickshell.execDetached(["wl-copy", String(cl.modelData.text)]); win.open = false } }
            }
          }
          Text { anchors { left: parent.left; bottom: parent.bottom } text: T.t("Clic : copier"); color: win.sub; font.family: win.font; font.pixelSize: 10 }
          Text { anchors { right: parent.right; bottom: parent.bottom } text: win.clips.length + T.t(" éléments"); color: win.sub; font.family: win.font; font.pixelSize: 10 }
        }

        // ---------- Texte
        Item {
          anchors.fill: parent
          visible: win.tab === "text"
          Rectangle {
            width: parent.width - 230; height: parent.height - 26; radius: 12; color: win.tile
            Flickable {
              anchors.fill: parent; anchors.margins: 12
              contentHeight: edit.implicitHeight; clip: true
              TextEdit {
                id: edit
                width: parent.width
                color: win.ink; selectionColor: "#7c74c8"
                font.family: win.font; font.pixelSize: 13; wrapMode: TextEdit.Wrap
              }
            }
          }
          Text {
            anchors { left: parent.left; bottom: parent.bottom }
            text: edit.text.length + T.t(" car.") + " · " + edit.text.replace(/\s/g, "").length + T.t(" sans espaces") + " · "
                  + (edit.text.trim() === "" ? 0 : edit.text.trim().split(/\s+/).length) + T.t(" mots") + " · " + (edit.text === "" ? 0 : edit.text.split("\n").length) + T.t(" lignes")
            color: win.sub; font.family: win.font; font.pixelSize: 10
          }
          Row {
            anchors { right: parent.right; rightMargin: 234; bottom: parent.bottom }
            spacing: 10
            MIcon { icon: "content_paste_go"; size: 14; color: win.sub; TapHandler { onTapped: edit.paste() } }
            MIcon { icon: "content_copy"; size: 14; color: win.sub; TapHandler { onTapped: Quickshell.execDetached(["wl-copy", edit.text]) } }
          }
          Grid {
            anchors.right: parent.right; columns: 2; spacing: 6
            Repeater {
              model: [[T.t("MAJUSCULES"), "up"], [T.t("minuscules"), "low"], [T.t("Chaque Mot"), "word"], [T.t("Phrase"), "sent"],
                      [T.t("Sans retours"), "lines"], [T.t("Sans doubles espaces"), "space"], [T.t("JSON lisible"), "pretty"], [T.t("JSON compact"), "min"],
                      ["→ Base64", "b64"], ["Base64 →", "unb64"]]
              Rectangle {
                id: tt
                required property var modelData
                width: 108; height: 34; radius: 9
                color: ttHover.hovered ? win.tile2 : win.tile
                Text { anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: tt.modelData[0]; color: win.ink; font.family: win.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                HoverHandler { id: ttHover }
                TapHandler { onTapped: edit.text = win.convert(edit.text, tt.modelData[1]) }
              }
            }
          }
        }

        // ---------- Étagère
        Item {
          anchors.fill: parent
          visible: win.tab === "shelf"
          Column {
            visible: win.shelf.length === 0
            anchors.centerIn: parent; spacing: 8
            MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "inbox"; size: 30; color: win.sub }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: T.t("Étagère vide"); color: win.ink; font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: T.t("Glisse des fichiers sur l'île, ils restent ici jusqu'à ce que tu les retires"); color: win.sub; font.family: win.font; font.pixelSize: 11 }
          }
          ListView {
            id: shelfList
            anchors.fill: parent; clip: true; spacing: 6
            model: win.shelf
            delegate: Rectangle {
              id: sf
              required property var modelData
              required property int index
              width: shelfList.width; height: 42; radius: 10; color: win.tile
              Text { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60; text: sf.modelData.split("/").pop(); color: win.ink; font.family: win.font; font.pixelSize: 12; elide: Text.ElideMiddle; textFormat: Text.PlainText }
              TapHandler { onTapped: { win.open = false; Quickshell.execDetached(["xdg-open", sf.modelData]) } }
              MIcon {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                icon: "close"; size: 15; color: win.sub
                TapHandler { onTapped: { var l = win.shelf.slice(); l.splice(sf.index, 1); win.saveShelf(l) } }
              }
            }
          }
          DropArea { anchors.fill: parent; onDropped: function(d) { win.addFiles(d.urls) } }
        }

        // ---------- Chat
        Item {
          anchors.fill: parent
          visible: win.tab === "chat"
          Column {
            visible: win.chat.length === 0
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 4 }
            spacing: 8
            Row {
              anchors.horizontalCenter: parent.horizontalCenter; spacing: 16
              Repeater {
                model: 2
                Rectangle {
                  width: 14; height: 26; radius: 7; color: win.ink
                  SequentialAnimation on height { loops: Animation.Infinite; running: win.open && win.tab === "chat"
                    PauseAnimation { duration: 2800 } NumberAnimation { to: 3; duration: 90 } NumberAnimation { to: 26; duration: 110 } }
                }
              }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: T.t("Demande ce que tu veux"); color: win.ink; font.family: win.font; font.pixelSize: 16; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Claude · " + T.t("Entrée pour envoyer"); color: win.sub; font.family: win.font; font.pixelSize: 11 }
            Repeater {
              model: [T.t("Explique simplement comment marche un VPN"), T.t("Aide-moi à écrire un message poli"), T.t("Donne-moi cinq idées pour le week-end")]
              Rectangle {
                id: sug
                required property var modelData
                anchors.horizontalCenter: parent.horizontalCenter
                width: sugT.implicitWidth + 32; height: 30; radius: 15; color: win.tile2
                Text { id: sugT; anchors.centerIn: parent; text: sug.modelData; color: win.ink; font.family: win.font; font.pixelSize: 12 }
                TapHandler { onTapped: win.ask(sug.modelData) }
              }
            }
          }
          ListView {
            id: chatList
            anchors { fill: parent; bottomMargin: 50 }
            clip: true; spacing: 8
            model: win.chat
            onCountChanged: positionViewAtEnd()
            delegate: Item {
              id: msg
              required property var modelData
              width: chatList.width; height: bubble.height
              Rectangle {
                id: bubble
                anchors.right: msg.modelData.me ? parent.right : undefined
                width: Math.min(parent.width * 0.82, bt.implicitWidth + 24); height: bt.implicitHeight + 16; radius: 12
                color: msg.modelData.me ? win.tile2 : win.tile
                TextEdit { id: bt; x: 12; y: 8; width: Math.min(chatList.width * 0.82 - 24, implicitWidth); readOnly: true; selectByMouse: true; text: msg.modelData.text; color: win.ink; font.family: win.font; font.pixelSize: 13; wrapMode: TextEdit.Wrap; textFormat: TextEdit.PlainText }
              }
            }
          }
          Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 42; radius: 21; color: win.tile2
            MIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; icon: "attach_file"; size: 16; color: win.sub }
            TextInput {
              id: prompt
              anchors { left: parent.left; leftMargin: 40; right: parent.right; rightMargin: 48; verticalCenter: parent.verticalCenter }
              color: win.ink; font.family: win.font; font.pixelSize: 13; clip: true
              onAccepted: { win.ask(text); text = "" }
              Text { visible: prompt.text === ""; text: askP.running ? T.t("Réflexion…") : T.t("Message pour l'IA…"); color: win.sub; font: prompt.font }
            }
            Rectangle {
              anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
              width: 30; height: 30; radius: 15; color: win.sub
              MIcon { anchors.centerIn: parent; icon: "arrow_upward"; size: 17; color: "#000000" }
              TapHandler { onTapped: { win.ask(prompt.text); prompt.text = "" } }
            }
          }
        }

        // ---------- Notes
        Item {
          anchors.fill: parent
          visible: win.tab === "notes"
          Rectangle {
            width: parent.width - 196; height: parent.height; radius: 12; color: win.tile
            Flickable {
              anchors.fill: parent; anchors.margins: 12
              contentHeight: notes.implicitHeight; clip: true
              TextEdit {
                id: notes
                width: parent.width
                color: win.ink; selectionColor: "#7c74c8"; font.family: win.font; font.pixelSize: 13; wrapMode: TextEdit.Wrap
                onTextChanged: if (win.notesReady) saveNotes.restart()
                Text { visible: notes.text === ""; width: parent.width; wrapMode: Text.WordWrap; text: T.t("Écris ici : numéro de commande, liste, bout de code. Tout s'enregistre seul."); color: win.sub; font: notes.font }
              }
            }
          }
          Rectangle {
            anchors.right: parent.right
            width: 186; height: parent.height; radius: 12; color: win.tile
            Canvas {
              id: ring
              x: (parent.width - 110) / 2; y: 14; width: 110; height: 110
              property real p: win.timerTotal > 0 ? win.timerLeft / win.timerTotal : 1
              onPChanged: requestPaint()
              onPaint: {
                var c = getContext("2d")
                c.reset(); c.lineWidth = 7; c.lineCap = "round"
                c.strokeStyle = "#2a272e"; c.beginPath(); c.arc(55, 55, 48, 0, Math.PI * 2); c.stroke()
                c.strokeStyle = "#e39a4f"; c.beginPath(); c.arc(55, 55, 48, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p); c.stroke()
              }
              Text { anchors.centerIn: parent; text: win.s.fmtTime(win.timerLeft); color: win.ink; font.family: win.font; font.pixelSize: 20; font.weight: Font.DemiBold }
              TapHandler { onTapped: tick.running = !tick.running }
            }
            Row {
              x: (parent.width - width) / 2; y: 134; spacing: 5
              Repeater {
                model: [5, 10, 15, 25, 45]
                Rectangle {
                  id: pr
                  required property int modelData
                  width: 28; height: 24; radius: 7; color: win.timerTotal === modelData * 60 ? "#e39a4f" : win.tile2
                  Text { anchors.centerIn: parent; text: pr.modelData; color: win.timerTotal === pr.modelData * 60 ? "#000000" : win.ink; font.family: win.font; font.pixelSize: 11 }
                  TapHandler { onTapped: { win.timerTotal = pr.modelData * 60; win.timerLeft = win.timerTotal; tick.running = true } }
                }
              }
            }
            Text {
              x: 14; y: 170; width: parent.width - 28; wrapMode: Text.WordWrap
              text: tick.running ? T.t("Clic sur l'anneau : pause") : T.t("Choisis une durée, une notification te préviendra.")
              color: win.sub; font.family: win.font; font.pixelSize: 11
            }
          }
        }

        // ---------- Météo
        Item {
          anchors.fill: parent
          visible: win.tab === "weather"
          readonly property var w: win.s.weather
          Rectangle {
            width: 220; height: parent.height; radius: 14
            gradient: Gradient {
              GradientStop { position: 0; color: "#5d8fd0" }
              GradientStop { position: 1; color: "#b4c6dc" }
            }
            Column {
              x: 14; y: 12; width: parent.width - 28; spacing: 4
              Text { text: parent.parent.parent.w ? parent.parent.parent.w.city : win.s.city; color: "#ffffff"; font.family: win.font; font.pixelSize: 11; textFormat: Text.PlainText }
              Row {
                spacing: 8
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: win.s.weatherIcon; size: 36; fill: 1; color: "#ffe9b0" }
                Text { text: parent.parent.parent.parent.w ? parent.parent.parent.parent.w.temp + "°" : "--"; color: "#ffffff"; font.family: win.font; font.pixelSize: 40; font.weight: Font.DemiBold }
              }
              Text { text: win.s.weatherDesc; color: "#ffffff"; font.family: win.font; font.pixelSize: 13; font.weight: Font.DemiBold }
              Text { text: parent.parent.parent.w ? T.t("Ressenti ") + parent.parent.parent.w.feels + "°  ·  " + parent.parent.parent.w.max + "° / " + parent.parent.parent.w.min + "°" : ""; color: "#eef3fa"; font.family: win.font; font.pixelSize: 11 }
            }
            Row {
              anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 12 }
              spacing: 6
              Repeater {
                model: parent.parent.parent.w ? [[parent.parent.parent.w.wind + " km/h", "air"], [parent.parent.parent.w.humidity + " %", "humidity_percentage"], [parent.parent.parent.w.rain + " %", "rainy"]] : []
                Rectangle {
                  id: stat
                  required property var modelData
                  width: 60; height: 50; radius: 10; color: Qt.rgba(1, 1, 1, 0.22)
                  Column {
                    anchors.centerIn: parent; spacing: 2
                    MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: stat.modelData[1]; size: 15; color: "#ffffff" }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: stat.modelData[0]; color: "#ffffff"; font.family: win.font; font.pixelSize: 10 }
                  }
                }
              }
            }
          }
          Rectangle {
            x: 228; width: parent.width - 228; height: 70; radius: 12; color: win.tile
            Row {
              anchors.centerIn: parent; spacing: 4
              Repeater {
                model: parent.parent.parent.w ? parent.parent.parent.w.hourly.slice(0, 8) : []
                Column {
                  id: hr
                  required property var modelData
                  width: (page.width - 228 - 40) / 8; spacing: 2
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.h; color: win.sub; font.family: win.font; font.pixelSize: 9 }
                  MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: win.s.weatherInfo(hr.modelData.code)[1]; size: 16; fill: 1; color: "#e8c46a" }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.temp + "°"; color: win.ink; font.family: win.font; font.pixelSize: 11 }
                }
              }
            }
          }
          Rectangle {
            x: 228; y: 78; width: parent.width - 228; height: parent.height - 78; radius: 12; color: win.tile
            Column {
              anchors.centerIn: parent; width: parent.width - 28; spacing: 7
              Repeater {
                model: parent.parent.parent.w && parent.parent.parent.w.days ? parent.parent.parent.w.days : []
                Row {
                  id: dy
                  required property var modelData
                  required property int index
                  spacing: 10
                  Text { width: 62; text: dy.index === 0 ? T.t("Aujourd'hui") : new Date(dy.modelData.day).toLocaleDateString(Qt.locale(T.loc), "ddd"); color: win.ink; font.family: win.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                  Text { width: 26; horizontalAlignment: Text.AlignRight; text: dy.modelData.min + "°"; color: win.sub; font.family: win.font; font.pixelSize: 11 }
                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter; width: page.width - 228 - 28 - 62 - 26 - 30 - 30; height: 3; radius: 2; color: win.tile2
                    Rectangle {
                      x: parent.width * Math.max(0, (dy.modelData.min + 5) / 45)
                      width: parent.width * Math.max(0.06, (dy.modelData.max - dy.modelData.min) / 45)
                      height: 3; radius: 2
                      gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#7fb0d8" } GradientStop { position: 1; color: "#e8b06a" } }
                    }
                  }
                  Text { width: 26; text: dy.modelData.max + "°"; color: win.ink; font.family: win.font; font.pixelSize: 11 }
                }
              }
            }
          }
        }

        // ---------- Contrôles
        Item {
          anchors.fill: parent
          visible: win.tab === "manage"
          Row {
            spacing: 8
            Repeater {
              model: [[win.s.netWifi ? "wifi" : "lan", win.s.netWifi ? "Wi-Fi" : "Ethernet", win.s.netDev !== "" ? T.t("Connecté") : T.t("Déconnecté"), win.s.netDev !== "", "nm-connection-editor"],
                      ["bluetooth", "Bluetooth", T.t("Réglages"), false, "omarchy-bluetooth-power toggle"],
                      ["dark_mode", T.t("Thème sombre"), T.t("Activé"), true, "liquid-glass mode toggle"]]
              Rectangle {
                id: mt
                required property var modelData
                width: (page.width - 16) / 3; height: 180; radius: 14
                color: modelData[3] ? win.tile2 : win.tile
                Rectangle {
                  x: 14; y: 14; width: 38; height: 38; radius: 19; color: mt.modelData[3] ? "#7c74c8" : win.tile2
                  MIcon { anchors.centerIn: parent; icon: mt.modelData[0]; size: 20; color: "#ffffff" }
                }
                Column {
                  x: 14; anchors { bottom: parent.bottom; bottomMargin: 14 }
                  Text { text: mt.modelData[1]; color: win.ink; font.family: win.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                  Text { text: mt.modelData[2]; color: win.sub; font.family: win.font; font.pixelSize: 11 }
                }
                TapHandler { onTapped: win.s.run(mt.modelData[4]) }
              }
            }
          }
          Row {
            y: 190; spacing: 8
            Repeater {
              model: [["lock", T.t("Verrouiller"), "lock"], ["bedtime", T.t("Suspendre"), "suspend"], ["restart_alt", T.t("Redémarrer"), "reboot"], ["power_settings_new", T.t("Éteindre"), "off"]]
              Rectangle {
                id: pb
                required property var modelData
                width: (page.width - 24) / 4; height: page.height - 190; radius: 14
                color: pbHover.hovered ? win.tile2 : win.tile
                Column {
                  anchors.centerIn: parent; spacing: 4
                  MIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: pb.modelData[0]; size: 20; color: win.ink }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: pb.modelData[1]; color: win.ink; font.family: win.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                }
                HoverHandler { id: pbHover }
                TapHandler {
                  onTapped: {
                    win.open = false
                    if (pb.modelData[2] === "off") win.s.panel = "ile-off"
                    else win.s.power(pb.modelData[2])
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    var t = String(Quickshell.env("LG_ILE") || "")
    if (t === "note") notify("check", "Claude a terminé", "Les agents de Claude Code se partagent le travail.", "#2d6a4f")
    else if (t !== "") { tab = t; open = true }
  }

  // ---------- Données
  property var clips: []
  FileView {
    path: win.home + "/.local/state/omarchy/clipboard-history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var d = JSON.parse(text()); win.clips = Array.isArray(d) ? d : (d.items || d.entries || []) } catch (e) {} }
  }

  property var shelf: []
  function saveShelf(l) { shelf = l; shelfFile.setText(JSON.stringify(l) + "\n") }
  function addFiles(urls) {
    var l = shelf.slice()
    for (var i = 0; i < urls.length; i++) {
      var p = decodeURIComponent(String(urls[i]).replace(/^file:\/\//, ""))
      if (l.indexOf(p) < 0) l.push(p)
    }
    saveShelf(l)
  }
  FileView {
    id: shelfFile
    path: win.stateDir + "/ile-shelf.json"
    printErrors: false
    onLoaded: { try { var d = JSON.parse(text()); if (Array.isArray(d)) win.shelf = d } catch (e) {} }
  }

  property bool notesReady: false
  FileView {
    id: notesFile
    path: win.stateDir + "/ile-notes.txt"
    printErrors: false
    onLoaded: { notes.text = text(); win.notesReady = true }
    onLoadFailed: win.notesReady = true
  }
  Timer { id: saveNotes; interval: 800; onTriggered: notesFile.setText(notes.text) }

  property int timerTotal: 300
  property int timerLeft: 300
  Timer {
    id: tick
    interval: 1000; repeat: true
    onTriggered: {
      win.timerLeft--
      if (win.timerLeft <= 0) {
        running = false
        win.timerLeft = win.timerTotal
        win.notify("timer", T.t("Minuteur terminé"), "", "#b5722e")
      }
    }
  }

  function convert(t, how) {
    try {
      if (how === "up") return t.toUpperCase()
      if (how === "low") return t.toLowerCase()
      if (how === "word") return t.toLowerCase().replace(/(^|[\s'’-])(\S)/g, function(m, a, b) { return a + b.toUpperCase() })
      if (how === "sent") return t.toLowerCase().replace(/(^\s*|[.!?]\s+)(\S)/g, function(m, a, b) { return a + b.toUpperCase() })
      if (how === "lines") return t.replace(/\s*\n\s*/g, " ")
      if (how === "space") return t.replace(/[ \t]+/g, " ").trim()
      if (how === "pretty") return JSON.stringify(JSON.parse(t), null, 2)
      if (how === "min") return JSON.stringify(JSON.parse(t))
      if (how === "b64") return Qt.btoa(t)
      if (how === "unb64") return Qt.atob(t)
    } catch (e) {}
    return t
  }

  // Chat : la question part à Claude en argument, jamais dans un shell.
  property var chat: []
  function ask(q) {
    q = String(q || "").trim()
    if (q === "" || askP.running) return
    chat = chat.concat([{ me: true, text: q }])
    askP.command = chat.length > 1 ? ["claude", "-p", "--continue", q] : ["claude", "-p", q]
    askP.running = true
  }
  Process {
    id: askP
    stdout: StdioCollector { onStreamFinished: { var t = text.trim(); win.chat = win.chat.concat([{ me: false, text: t !== "" ? t : T.t("Pas de réponse : Claude est-il connecté ?") }]) } }
  }

  // Notifications : l'encoche reprend celles d'Omarchy et l'état de la touche Verr. maj.
  function notify(icon, title, body, tint) {
    note = { icon: icon, title: title, body: body, tint: tint }
    noteOff.restart()
  }
  Timer { id: noteOff; interval: win.s.testing ? 60000 : 4500; onTriggered: win.note = null }
  property real lastTs: -1
  FileView {
    path: win.home + "/.local/state/omarchy/notifications/history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var d = JSON.parse(text())
        if (!Array.isArray(d) || !d.length) return
        var ts = Number(d[0].ts || 0)
        if (win.lastTs >= 0 && ts > win.lastTs) win.notify("check", String(d[0].summary || d[0].app || ""), String(d[0].body || "").replace(/<[^>]*>/g, ""), "#2d6a4f")
        win.lastTs = ts
      } catch (e) {}
    }
  }
  property int caps: -1
  Process {
    id: capsP
    command: ["sh", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null | sort -rn | head -1"]
    stdout: StdioCollector {
      onStreamFinished: {
        var v = parseInt(text) > 0 ? 1 : 0
        if (win.caps >= 0 && v !== win.caps) win.notify(v ? "keyboard_capslock" : "keyboard", v ? T.t("Verr. maj. activé") : T.t("Verr. maj. désactivé"), "", "#b5722e")
        win.caps = v
      }
    }
  }
  Timer { interval: 700; repeat: true; running: !win.s.testing; onTriggered: if (!capsP.running) capsP.running = true }
}
