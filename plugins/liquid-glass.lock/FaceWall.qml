import QtQuick
import QtQuick.Effects

// Fond des écrans personnalisés : la vidéo choisie pour le verrouillage ([lock] video,
// ou le fond d'écran s'il est une vidéo), sinon l'image, qui avance très lentement
// ([lock] drift). Flou et luminosité réglables.
Item {
  id: w
  property var lk: null
  property real blur: 0
  property real brightness: 0
  property real saturation: 0
  property color tint: "transparent"
  readonly property string videoPath: lk ? lk.lockVideo : ""
  clip: true
  Image {
    id: img
    anchors.centerIn: parent
    width: parent.width; height: parent.height
    source: w.videoPath !== "" ? "" : (w.lk && w.lk.backgroundPath && !w.lk.video ? "file://" + w.lk.backgroundPath : (w.lk && w.lk.videoPosterPath ? "file://" + w.lk.videoPosterPath : ""))
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(w.width * 1.1, w.height * 1.1)
    visible: false
  }
  LockVideo {
    id: vid
    anchors.fill: parent
    path: w.videoPath
    active: w.videoPath !== "" && w.visible
    visible: w.videoPath !== ""
    layer.enabled: w.videoPath !== ""
  }
  MultiEffect {
    id: fx
    anchors.centerIn: parent
    width: parent.width; height: parent.height
    source: w.videoPath !== "" ? vid : img
    blurEnabled: w.blur > 0; blurMax: 64; blur: w.blur
    brightness: w.brightness; saturation: w.saturation
    // Mouvement lent du fond fixe (zoom et glissement sur une minute).
    property real t: 0
    SequentialAnimation on t {
      running: w.videoPath === "" && !!w.lk && w.lk.drift
      loops: Animation.Infinite
      NumberAnimation { from: 0; to: 1; duration: 32000; easing.type: Easing.InOutSine }
      NumberAnimation { from: 1; to: 0; duration: 32000; easing.type: Easing.InOutSine }
    }
    scale: 1 + 0.07 * t
    transform: Translate { x: (fx.t - 0.5) * w.width * 0.025; y: (0.5 - fx.t) * w.height * 0.015 }
  }
  Rectangle { anchors.fill: parent; color: w.tint }
}
