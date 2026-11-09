import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// ============================================================================
// Masquer automatiquement la barre des menus (Réglages → Barre des menus),
// comme macOS : la barre est rangée hors de l'écran (drapeau `bar-off`
// d'Omarchy, les fenêtres prennent toute la hauteur) ; amener la souris tout
// en haut la fait redescendre, elle repart quand la souris s'en éloigne, sauf
// pendant qu'un menu ou un panneau de la barre est ouvert.
//   ~/.config/liquid-glass/config.json : menubar.autohide = "never" | "always"
// ============================================================================
Item {
  id: ah
  property QtObject bar: null        // API de la barre (activePopout, barSize)
  property bool menuOpen: false      // un menu de ce plugin est déroulé
  property var screen: null

  readonly property string home: Quickshell.env("HOME")
  property string mode: "never"
  // Profil Mac seulement : les bureaux Linux / Omarchy n'ont rien à voir avec cette barre.
  property string profile: ""
  // Plusieurs écrans : une instance du widget par barre, mais un seul drapeau
  // `bar-off` : seule celle du premier écran s'en occupe.
  readonly property bool active: mode === "always" && profile === "mac"
    && (!screen || Quickshell.screens.length === 0 || screen.name === Quickshell.screens[0].name)
  property bool revealed: false
  property bool applied: false        // dernier état écrit : barre cachée ?
  readonly property bool wantHidden: active && !revealed
  readonly property int barH: bar && bar.barSize ? bar.barSize : 24
  readonly property bool busy: menuOpen || (!!bar && !!bar.activePopout)

  FileView {
    path: ah.home + "/.config/liquid-glass/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var c = JSON.parse(text()), m = c.menubar || {}
        ah.mode = String(m.autohide || "never")
        ah.profile = String((c.profile && c.profile.active) || "mac")
      } catch (e) {}
    }
  }

  function write(hidden) {
    if (hidden === applied) return
    applied = hidden
    Quickshell.execDetached(["sh", "-c",
      (hidden ? "mkdir -p \"$HOME/.local/state/omarchy/toggles\" && touch \"$HOME/.local/state/omarchy/toggles/bar-off\""
              : "rm -f \"$HOME/.local/state/omarchy/toggles/bar-off\"")
      // Deux relances : la surveillance du dossier par la barre peut rater la première.
      + "; omarchy-shell -q omarchy.bar syncHidden; sleep 0.5; omarchy-shell -q omarchy.bar syncHidden"])
  }
  // Sortie du profil Mac : on ne touche plus au drapeau (le profil Linux cache la barre).
  onWantHiddenChanged: if (profile === "mac") write(wantHidden); else applied = false
  Component.onCompleted: {
    // Au démarrage, partir d'un état connu, mais seulement si le masquage auto
    // est actif : sinon on ne touche pas à une barre masquée à la main.
    if (wantHidden) { applied = false; write(true) }
  }
  // Profil Linux ou plugin retiré : on rend la barre.
  // Seulement si on est encore sur le profil Mac (sinon la barre Mac réapparaissait sur Linux).
  Component.onDestruction: if (applied && profile === "mac") Quickshell.execDetached(["sh", "-c",
    "sleep 0.5; grep -q '\"active\": *\"mac\"' \"$HOME/.config/liquid-glass/config.json\" || exit 0; "
    + "rm -f \"$HOME/.local/state/omarchy/toggles/bar-off\"; omarchy-shell -q omarchy.bar syncHidden"])

  // Bord chaud : 2 px en haut de l'écran, seulement quand la barre est rangée.
  PanelWindow {
    screen: ah.screen
    visible: ah.active && !ah.revealed
    anchors { top: true; left: true; right: true }
    implicitHeight: 2
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "liquid-glass-menubar-edge"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: showDelay.restart()
      onExited: showDelay.stop()
      onPressed: { ah.revealed = true; leave.count = 0 }
    }
  }
  // Petit délai comme sur Mac (évite les apparitions en passant).
  Timer { id: showDelay; interval: 180; onTriggered: { ah.revealed = true; leave.count = 0 } }

  // Barre sortie : la souris est-elle encore dessus ? (hyprctl cursorpos, coordonnées logiques)
  Process {
    id: cursorP
    command: ["hyprctl", "cursorpos"]
    stdout: StdioCollector {
      onStreamFinished: {
        var y = Number(String(text).split(",")[1])
        var top = ah.screen ? ah.screen.y : 0
        if (isNaN(y)) return
        if (ah.busy || y - top <= ah.barH + 6) leave.count = 0
        else if (++leave.count >= 2) ah.revealed = false
      }
    }
  }
  Timer {
    id: leave
    property int count: 0
    interval: 300
    repeat: true
    running: ah.active && ah.revealed
    onTriggered: if (!cursorP.running) cursorP.running = true
  }
}
