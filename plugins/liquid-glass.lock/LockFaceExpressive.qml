import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "T.js" as T

// Verrouillage du style Expressive (Material 3 « expressive ») : l'heure sur deux formes
// qui tournent lentement (biscuit à douze bosses pour les heures, fleur pour les minutes),
// la date dans une pastille, l'avatar dans un rond, un champ pilule et un gros bouton.
// Couleurs : celles calculées depuis le fond (cache m3 du bureau), sinon bleu Material.
Item {
  id: f
  property var lock: null
  readonly property var lk: lock
  readonly property real k: Math.min(width / 1280, height / 720)
  property var m3: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.cache/liquid-glass/m3/current.json"
    printErrors: false
    onLoaded: { try { f.m3 = JSON.parse(text()) } catch (e) {} }
  }
  function mc(key, d) { var c = f.m3[key] || (f.m3.colors && f.m3.colors[key]); return c ? c : d }
  readonly property color primary: mc("primary", "#adc6ff")
  readonly property color onPrimary: mc("on_primary", "#102f60")
  readonly property color pc: mc("primary_container", "#284777")
  readonly property color tc: mc("tertiary_container", "#57395d")
  readonly property color onPc: mc("on_primary_container", "#d8e2ff")
  readonly property color surf: mc("surface_container_high", "#282a2f")
  readonly property color ink: mc("on_surface", "#e2e2e9")
  readonly property int typed: lk ? lk.passwordText.length : 0
  readonly property rect fieldBox: {
    var c = field.mapToItem(f, 0, 0)
    return Qt.rect(c.x, c.y, field.width, field.height)
  }

  FaceWall { anchors.fill: parent; lk: f.lk; blur: 0.6; brightness: -0.3 }

  component Blob: Shape {
    id: blob
    property int bumps: 12
    property real depth: 0.08
    property color fill: "white"
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: blob.fill; strokeColor: "transparent"
      PathPolyline {
        path: {
          var pts = [], n = 120, r = blob.width / 2
          for (var i = 0; i <= n; i++) {
            var a = i / n * Math.PI * 2, rr = r * (1 - blob.depth + blob.depth * Math.cos(a * blob.bumps))
            pts.push(Qt.point(r + rr * Math.cos(a), r + rr * Math.sin(a)))
          }
          return pts
        }
      }
    }
  }

  Row {
    id: clock
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.1
    spacing: -20 * f.k
    Repeater {
      model: [[f.lk ? f.lk.hh : "", 12, 0.07, f.pc, f.onPc, 60000], [f.lk ? f.lk.mm : "", 6, 0.13, f.tc, f.onPc, -45000]]
      Item {
        id: cell
        required property var modelData
        required property int index
        width: 250 * f.k; height: width
        Blob {
          anchors.fill: parent; bumps: cell.modelData[1]; depth: cell.modelData[2]; fill: cell.index === 0 ? f.pc : f.tc
          NumberAnimation on rotation { from: 0; to: 360; duration: Math.abs(cell.modelData[5]); loops: Animation.Infinite }
        }
        Text { anchors.centerIn: parent; text: cell.modelData[0]; color: f.onPc
               font.family: "Google Sans Flex"; font.pixelSize: 120 * f.k; font.variableAxes: ({ "wght": 800, "ROND": 100, "wdth": 110 }) }
      }
    }
  }
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: clock.bottom; anchors.topMargin: 14 * f.k
    width: dt.implicitWidth + 32 * f.k; height: 36 * f.k; radius: height / 2; color: f.surf
    Text { id: dt; anchors.centerIn: parent; text: f.lk ? f.lk.now.toLocaleDateString(Qt.locale(T.loc), "dddd d MMMM") : ""
           font.family: "Google Sans Flex"; font.pixelSize: 15 * f.k; font.weight: Font.Medium; color: f.ink }
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    y: f.height * 0.7
    spacing: 10 * f.k
    ClippingRectangle {
      width: 52 * f.k; height: width; radius: width / 2; color: f.pc
      Image { anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(120, 120) }
    }
    Rectangle {
      id: field
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 0
      x: f.lk ? f.lk.shakeX : 0
      width: 300 * f.k; height: 52 * f.k; radius: height / 2
      color: f.surf
      border.color: f.lk && f.lk.errorState ? "#ffb4ab" : "transparent"; border.width: 2
      Text {
        x: 22 * f.k; anchors.verticalCenter: parent.verticalCenter; visible: f.typed === 0
        text: f.lk && f.lk.authenticatingPassword ? T.t("Vérification…") : f.lk && f.lk.errorState ? f.lk.failureMessage : T.t("Mot de passe")
        font.family: "Google Sans Flex"; font.pixelSize: 15 * f.k; color: f.lk && f.lk.errorState ? "#ffb4ab" : Qt.rgba(f.ink.r, f.ink.g, f.ink.b, 0.6)
      }
      Row {
        x: 22 * f.k; anchors.verticalCenter: parent.verticalCenter; spacing: 4 * f.k
        Repeater {
          model: Math.min(14, f.typed)
          Blob { required property int index; width: 14 * f.k; height: width; bumps: [4, 5, 6, 8][index % 4]; depth: 0.14; fill: f.primary
                 scale: 0; Component.onCompleted: scale = 1; Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } } }
        }
      }
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 52 * f.k; height: width; radius: goMa.pressed ? 14 * f.k : width / 2; color: f.primary
      Behavior on radius { NumberAnimation { duration: 160 } }
      Text { anchors.centerIn: parent; text: "arrow_forward"; font.family: "Material Symbols Rounded"; font.pixelSize: 24 * f.k; color: f.onPrimary }
      MouseArea { id: goMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) f.lk.accept() }
    }
  }
  Rectangle {
    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 20 * f.k
    width: 44 * f.k; height: width; radius: 14 * f.k; color: f.surf
    Text { anchors.centerIn: parent; text: "power_settings_new"; font.family: "Material Symbols Rounded"; font.pixelSize: 20 * f.k; color: f.ink }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (f.lk) { f.lk.powerOpen = !f.lk.powerOpen; f.lk.forcePasswordFocus() } }
  }
}
