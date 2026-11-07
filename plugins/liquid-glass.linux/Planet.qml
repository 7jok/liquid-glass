import QtQuick

// Sphère éclairée par cosmos/sphere.frag : elle tourne vraiment (texture
// équirectangulaire), avec une couche de nuages et un halo d'atmosphère.
ShaderEffect {
  id: root
  property url surfaceUrl
  property url cloudsUrl
  property real spin: 0
  property real cloudSpin: 0
  property real tilt: 0
  property real sunX: -0.75
  property real sunY: 0.35
  property real sunZ: 0.6
  property real cloudAmount: 0
  property real glow: 0.5
  property color rim: "#7fc8ff"

  Image { id: img; source: root.surfaceUrl; visible: false }
  Image { id: imgClouds; source: root.cloudsUrl; visible: false }
  property variant surface: img
  property variant clouds: imgClouds
  fragmentShader: Qt.resolvedUrl("cosmos/sphere.frag.qsb")
}
