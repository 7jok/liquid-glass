import QtQuick
import QtMultimedia

// Vidéo de fond de l'écran verrouillé : en boucle, sans le son, recadrée pour
// remplir l'écran. S'arrête quand elle n'est plus affichée.
Item {
  id: v
  property string path: ""
  property bool active: true
  readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
  MediaPlayer {
    id: player
    source: v.path !== "" ? "file://" + v.path : ""
    loops: MediaPlayer.Infinite
    videoOutput: out
    audioOutput: null
    onSourceChanged: if (v.active && source != "") play()
  }
  VideoOutput { id: out; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
  onActiveChanged: active ? player.play() : player.pause()
  Component.onCompleted: if (active && path !== "") player.play()
}
