import QtQuick
import QtQuick.Effects

// Fond des écrans personnalisés : le fond d'écran (ou l'image de la vidéo), flou et
// luminosité réglables.
Item {
  id: w
  property var lk: null
  property real blur: 0
  property real brightness: 0
  property real saturation: 0
  property color tint: "transparent"
  Image {
    id: img
    anchors.fill: parent
    source: w.lk && w.lk.backgroundPath && !w.lk.video ? "file://" + w.lk.backgroundPath : (w.lk && w.lk.videoPosterPath ? "file://" + w.lk.videoPosterPath : "")
    fillMode: Image.PreserveAspectCrop
    sourceSize: Qt.size(w.width, w.height)
    visible: false
  }
  MultiEffect {
    anchors.fill: parent; source: img
    blurEnabled: w.blur > 0; blurMax: 64; blur: w.blur
    brightness: w.brightness; saturation: w.saturation
  }
  Rectangle { anchors.fill: parent; color: w.tint }
}
