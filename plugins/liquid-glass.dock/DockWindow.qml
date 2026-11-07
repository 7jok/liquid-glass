import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DockModel.js" as DockModel
import "Mac.js" as Mac
import "T.js" as T

// One screen's dock. It stays mapped and only hides its contents, so switching
// to a floating workspace does not wait on a fresh layer surface. While hidden the
// mask is empty and clicks fall through to the windows below.
PanelWindow {
  id: window
  // Right-to-left languages read this window mirrored.
  Binding { target: window.contentItem; property: "LayoutMirroring.enabled"; value: Commons.I18n.rightToLeft }
  Binding { target: window.contentItem; property: "LayoutMirroring.childrenInherit"; value: true }


  property var dock: null

  readonly property string position: dock ? dock.position : "bottom"
  readonly property bool vertical: dock ? dock.vertical : false
  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property var workspace: monitor ? monitor.activeWorkspace : null
  readonly property int workspaceId: workspace ? workspace.id : -1
  // The most fullscreen window on the workspace, as Hyprland counts it: 1 is
  // maximized, and 2 or 3 fullscreen.
  readonly property int fullscreenMode: {
    var mode = 0
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      if (!toplevel.workspace || toplevel.workspace.id !== workspaceId) continue
      var ipc = toplevel.lastIpcObject
      mode = Math.max(mode, ipc && ipc.fullscreen ? ipc.fullscreen : 0)
    }
    return mode
  }
  readonly property bool shown: !!dock && dock.isFloating(workspaceId) && fullscreenMode < 2
  // With auto-hide on, the dock waits off screen until the pointer reaches its
  // edge, and stays while the pointer, a menu, or a drag still needs it. A
  // maximized window hides the dock the same way, so it can still be called up.
  readonly property bool autohide: !!dock && (dock.autohide || fullscreenMode === 1)
  property bool revealed: false
  readonly property bool menuOpen: menuItem !== null || settingsMenu || stackOpen
  readonly property bool tucked: autohide && !(revealed || menuOpen || previewOpen || dragging || insertIndex >= 0)
  readonly property bool contentShown: shown && !tucked

  readonly property int gap: Style.spacing.xs
  readonly property int iconSize: dock ? dock.iconSizeSetting : 44
  // Magnification façon macOS : facteur max et portée (en slots) de la vague.
  readonly property real magnify: dock ? dock.magnification : 1.6
  readonly property real waveSigma: slotSize * 1.15
  // Position du pointeur le long du dock (coordonnées de body), -1 = absent.
  readonly property real pointerAlong: bodyHover.hovered && !dragging && !hoverStale
    ? (vertical ? bodyHover.point.position.y : bodyHover.point.position.x) : -1
  // Dernière position connue : quand le pointeur sort, la vague retombe sur place.
  property real pointerAlongSmooth: -1
  onPointerAlongChanged: if (pointerAlong >= 0) pointerAlongSmooth = pointerAlong
  Behavior on pointerAlongSmooth { enabled: !Style.reduceMotion && window.waveStrength > 0.05; NumberAnimation { duration: Style.duration(60) } }
  property real waveStrength: pointerAlong >= 0 ? 1 : 0
  Behavior on waveStrength { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }

  // Grossissement d'une icône dont le centre est à `center` (coordonnées body).
  function waveScale(center) {
    if (window.waveStrength <= 0 || window.magnify <= 1) return 1
    var d = center - window.pointerAlongSmooth
    var g = Math.exp(-(d * d) / (2 * window.waveSigma * window.waveSigma))
    return 1 + (window.magnify - 1) * g * window.waveStrength
  }
  // Largeur supplémentaire d'une icône grossie.
  function waveExtra(index) {
    return (waveScale(slotCenter(index)) - 1) * window.iconSize
  }
  // Centre du slot n° index (0 = bouton Apps) le long du dock.
  function slotCenter(index) { return index * window.slotSize + window.slotSize / 2 }
  // Décalage pour écarter les voisines : chaque icône est poussée de la moitié
  // de la croissance des autres, du côté opposé.
  function waveShift(index) {
    if (window.waveStrength <= 0) return 0
    var count = (window.dock ? window.dock.itemModel.count : 0) + 3   // + bouton Apps + Téléchargements + Corbeille
    var before = 0, after = 0
    for (var i = 0; i < count; i++) {
      if (i < index) before += waveExtra(i)
      else if (i > index) after += waveExtra(i)
    }
    return (before - after) / 2
  }
  readonly property real waveTotal: {
    if (window.waveStrength <= 0) return 0
    var count = (window.dock ? window.dock.itemModel.count : 0) + 3
    var total = 0
    for (var i = 0; i < count; i++) total += waveExtra(i)
    return total
  }
  // Each app has a square slot with its icon in the middle, and the slots run
  // straight to the edge of the dock.
  // Tahoe : icônes serrées (≈ 4 pt de marge), le verre colle aux icônes.
  readonly property int iconInset: 4
  readonly property int slotSize: iconSize + iconInset * 2
  // A pinned app that is not running is drawn faded.
  readonly property real idleOpacity: 0.7
  // Room inward of the dock for its menus: the tallest, the apps button's,
  // has five rows.
  // La pile Téléchargements (éventail) demande plus de place que les menus.
  readonly property int popupRoom: Math.max(Style.spacing.popupRowHeight * 5 + Style.spacing.sm * 2 + Style.normalBorderWidth * 2 + gap * 2, stackRoom)
  readonly property int stackRoom: window.vertical ? 0 : 10 * 46 + 70
  property bool stackOpen: false
  // Icons pop away from the screen edge.
  readonly property int popOrigin: position === "top" ? Item.Top
    : position === "left" ? Item.Left
    : position === "right" ? Item.Right
    : Item.Bottom

  // The app being dragged along the dock, how far the pointer has taken it,
  // and the slot it would land in.
  property int dragIndex: -1
  property int dropIndex: -1
  property real dragOffset: 0
  readonly property bool dragging: dragIndex >= 0
  // Off while a drop resets the slots: they snap to where the reorder puts
  // them rather than sliding back from where they stepped aside. Set before
  // the drag state changes, so the slots never see the reset animated.
  property bool animateShifts: true
  // After a drop the slots have moved under a pointer that has not, so what
  // they think is hovered is stale until it moves again.
  property bool hoverStale: false
  property point dropPoint
  // Where an app dragged in from the app grid would land, or -1.
  property int insertIndex: -1

  // Where this window sits on its screen, which a point from the app grid's
  // fullscreen surface is given in: against its edge, clear of the space
  // other surfaces such as the bar reserve. Hyprland lists that space as
  // left, top, right, bottom.
  function origin() {
    var reserved = monitor && monitor.lastIpcObject && monitor.lastIpcObject.reserved ? monitor.lastIpcObject.reserved : [0, 0, 0, 0]
    var left = reserved[0] || 0, top = reserved[1] || 0, right = reserved[2] || 0, bottom = reserved[3] || 0
    var x = window.position === "right" ? screen.width - right - window.width : left
    var y = window.position === "bottom" ? screen.height - bottom - window.height : top
    return Qt.point(x, y)
  }

  // An app from the app grid lands where the pointer is, once it is over the
  // dock or close to it on the inward side.
  function moveExternalDrag(screenX, screenY) {
    var at = window.origin()
    var point = Qt.point(screenX - at.x - body.x, screenY - at.y - body.y)
    var reach = window.slotSize
    var along = window.vertical ? point.y : point.x
    var across = window.vertical ? point.x : point.y
    var length = window.vertical ? body.height : body.width
    var depth = window.vertical ? body.width : body.height
    var near = along >= -window.slotSize && along <= length + window.slotSize && across >= -reach && across <= depth + reach
    if (window.shown && window.autohide && near) window.revealed = true
    window.insertIndex = window.shown && near ? window.slotIndexAt(point) : -1
  }

  function dropExternalDrag(screenX, screenY, key) {
    window.moveExternalDrag(screenX, screenY)
    window.settleShifts()
    if (window.insertIndex >= 0 && key && window.dock) window.dock.pinAt(key, window.insertIndex)
    window.endExternalDrag()
  }

  function endExternalDrag() {
    window.insertIndex = -1
    if (window.autohide) hideTimer.restart()
  }

  // The slot a point along the dock falls before, counting from the first app.
  function slotIndexAt(point) {
    var along = window.vertical ? point.y : point.x
    var first = window.slotSize
    var count = window.dock ? window.dock.itemModel.count : 0
    return Math.max(0, Math.min(count, Math.round((along - first) / window.slotSize)))
  }
  property var menuItem: null
  property Item menuSlot: null
  // Comme macOS : apps du Dock | apps ouvertes non gardées | dossiers + Corbeille,
  // chaque groupe séparé par un trait.
  readonly property int firstRecent: {
    var items = dock ? dock.items : []
    for (var i = 1; i < items.length; i++) if (!items[i].pinned && items[i - 1].pinned) return i
    return -1
  }

  // Aperçus des fenêtres au survol d'une icône (façon DockDoor) : après un court
  // arrêt sur une app ouverte, ses fenêtres apparaissent en direct au-dessus.
  property string previewKey: ""
  property Item previewSlot: null
  property Item previewCandidate: null
  property bool previewHovered: false
  readonly property bool previewOpen: previewKey !== ""
  readonly property var previewItem: previewKey !== "" && dock ? dock.itemFor(previewKey) : null
  function hoverApp(slot, on) {
    if (on) {
      window.previewCandidate = slot
      previewCloseTimer.stop()
      // Déjà un aperçu ouvert : passer d'une icône à l'autre le suit sans délai.
      if (window.previewOpen) previewOpenTimer.interval = 90
      else previewOpenTimer.interval = 650
      previewOpenTimer.restart()
    } else {
      if (window.previewCandidate === slot) window.previewCandidate = null
      previewOpenTimer.stop()
      previewCloseTimer.restart()
    }
  }
  function openAt(kind, index) {
    var slot = appRepeater.itemAt(index)
    if (!slot) return
    window.revealed = true
    if (kind === "menu") window.openMenu(slot.modelData, slot)
    else if (slot.windowCount > 0) { window.previewSlot = slot; window.previewKey = slot.key }
  }
  function closePreview() {
    previewOpenTimer.stop()
    window.previewKey = ""
    window.previewSlot = null
  }
  Timer {
    id: previewOpenTimer
    onTriggered: {
      var slot = window.previewCandidate
      if (!slot || !slot.hovered || window.menuOpen || window.dragging || slot.windowCount === 0) {
        if (slot && slot.windowCount === 0 && !window.previewHovered) window.closePreview()
        return
      }
      window.previewSlot = slot
      window.previewKey = slot.key
    }
  }
  Timer {
    id: previewCloseTimer
    interval: 280
    onTriggered: if (!window.previewHovered && !window.previewCandidate) window.closePreview()
  }
  onMenuOpenChanged: if (menuOpen) closePreview()
  onDraggingChanged: if (dragging) closePreview()
  // ⌥ maintenue (écrite par Hyprland, voir liquid-glass-bindings.lua) :
  // « Quitter » devient « Forcer à quitter », comme sur macOS.
  property bool altHeld: false
  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/liquid-glass-alt"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: window.altHeld = text().trim() === "1"
    onLoadFailed: window.altHeld = false
  }
  // Options → Ouvrir à la connexion : état lu à l'ouverture du menu.
  property bool loginItem: false
  property bool optionsOpen: false
  Process {
    id: loginQuery
    stdout: StdioCollector { onStreamFinished: window.loginItem = text.trim() === "on" }
  }
  onMenuItemChanged: {
    window.optionsOpen = false
    window.loginItem = false
    if (menuItem) {
      loginQuery.command = ["liquid-glass", "login-item", String(menuItem.key), "status"]
      loginQuery.running = true
    }
  }
  // The apps button's menu: where the dock sits and whether it hides.
  property bool settingsMenu: false

  onWorkspaceIdChanged: if (dock) dock.readMode(workspaceId)
  onShownChanged: {
    if (shown) return
    closeMenu()
    window.revealed = false
  }
  Component.onCompleted: if (dock) dock.readMode(workspaceId)

  function openMenu(item, slot) {
    window.settingsMenu = false
    window.menuItem = item
    window.menuSlot = slot
  }

  function openSettingsMenu(slot) {
    window.menuItem = null
    window.settingsMenu = true
    window.menuSlot = slot
  }

  function settleShifts() {
    window.animateShifts = false
    Qt.callLater(function() { window.animateShifts = true })
  }

  function endDrag() {
    window.settleShifts()
    window.hoverStale = true
    window.dragIndex = -1
    window.dropIndex = -1
    window.dragOffset = 0
  }

  function closeMenu() {
    window.stackOpen = false
    window.menuItem = null
    window.settingsMenu = false
    window.menuSlot = null
    if (window.autohide) hideTimer.restart()
  }

  // Places the menu inward of the dock, centered on a slot.
  function popupX(slot, popup) {
    if (!slot) return 0
    var center = slot.mapToItem(window.contentItem, slot.width / 2, 0).x
    if (window.position === "left") return body.x + body.width + window.gap
    if (window.position === "right") return body.x - window.gap - popup.width
    return Math.max(window.gap, Math.min(window.width - popup.width - window.gap, center - popup.width / 2))
  }

  function popupY(slot, popup) {
    if (!slot) return 0
    var center = slot.mapToItem(window.contentItem, 0, slot.height / 2).y
    if (window.position === "top") return body.y + body.height + window.gap
    if (window.position === "bottom") return body.y - window.gap - popup.height
    return Math.max(window.gap, Math.min(window.height - popup.height - window.gap, center - popup.height / 2))
  }

  visible: !remapGuard.remapping
  color: "transparent"
  WlrLayershell.namespace: "omarchy-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  // Kept clear of the bar's reserved edge, without reserving one of its own:
  // floating windows go where they are put.
  exclusionMode: ExclusionMode.Normal
  // Toujours visible et sans masquage auto : les fenêtres en tuile évitent le dock.
  exclusiveZone: window.shown && !window.autohide && dock && dock.alwaysVisible ? window.slotSize + window.gap * 2 : 0

  anchors {
    top: window.position !== "bottom"
    bottom: window.position !== "top"
    left: window.position !== "right"
    right: window.position !== "left"
  }

  implicitWidth: window.vertical ? window.gap + window.slotSize + window.popupRoom : 0
  implicitHeight: window.vertical ? 0 : window.gap + window.slotSize + window.popupRoom

  mask: Region {
    item: window.contentShown ? body : null

    Region { item: window.shown && window.autohide ? edgeTrigger : null }
    Region { item: menu.visible ? menu : null }
    Region { item: stackFan.visible ? stackFan : null }
    Region { item: preview.visible ? preview : null }
  }

  onAutohideChanged: window.revealed = false

  Timer {
    id: hideTimer
    // Long enough to cross a gap between the edge and the icons, no longer.
    interval: 150
    onTriggered: {
      if (!bodyHover.hovered && !edgeHover.hovered && !window.menuOpen && !window.previewOpen && !window.dragging) window.revealed = false
    }
  }

  // The strip along the screen edge that brings an auto-hidden dock back.
  Item {
    id: edgeTrigger

    readonly property int depth: window.gap + Style.spacing.xxs

    x: window.position === "left" ? 0 : window.position === "right" ? window.width - depth : body.x
    y: window.position === "top" ? 0 : window.position === "bottom" ? window.height - depth : body.y
    width: window.vertical ? depth : body.width
    height: window.vertical ? body.height : depth

    HoverHandler {
      id: edgeHover
      onHoveredChanged: {
        if (hovered) window.revealed = true
        else hideTimer.restart()
      }
    }
  }

  ScreenMoveRemap {
    id: remapGuard
    window: window
  }

  HyprlandFocusGrab {
    active: window.menuOpen || window.stackOpen
    windows: [window]
    onCleared: window.closeMenu()
  }

  Item {
    id: body

    // The strip keeps its order in every language, like the bar: drags and
    // drops reckon slots along x from the first app. Only the menu mirrors.
    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    width: slots.implicitWidth
    height: slots.implicitHeight
    // How far the dock is tucked past its edge. Auto-hide slides it, but only
    // while the dock is on screen: arriving on a floating workspace shows it
    // where it belongs at once.
    property real tuck: window.tucked ? window.slotSize + window.gap : 0

    // Tucking away is quicker than coming back. A gentler curve than
    // Style.easeOut, which crosses the short slide in a frame or two.
    Behavior on tuck {
      id: tuckMotion
      enabled: window.shown
      NumberAnimation {
        duration: Style.duration(tuckMotion.targetValue > 0 ? 120 : 180)
        easing.type: Easing.OutCubic
      }
    }

    x: window.position === "left" ? window.gap - tuck
      : window.position === "right" ? window.width - width - window.gap + tuck
      : Math.round((window.width - width) / 2)
    y: window.position === "top" ? window.gap - tuck
      : window.position === "bottom" ? window.height - height - window.gap + tuck
      : Math.round((window.height - height) / 2)
    // Switching between tiled and floating workspaces shows and hides the dock
    // at once, with nothing to watch in between. Hidden by opacity rather than
    // visibility, so the icons keep their textures and are drawn on the first
    // frame back instead of being uploaded again.
    opacity: window.shown ? 1 : 0

    HoverHandler {
      id: bodyHover
      onHoveredChanged: if (!hovered && window.autohide) hideTimer.restart()
      // Only a real move clears it: the release itself reports the pointer too.
      onPointChanged: {
        if (!window.hoverStale || window.dragging) return
        var at = point.position
        if (Math.hypot(at.x - window.dropPoint.x, at.y - window.dropPoint.y) > Style.space(4)) window.hoverStale = false
      }
    }

    // Dock de macOS Tahoe : une fine plaque de verre très claire (presque
    // transparente, juste floutée par Hyprland), un liseré lumineux d'1 px et des
    // coins très arrondis ; plus de gros verre teinté derrière les icônes.
    Rectangle {
      id: glass
      readonly property real grow: window.waveTotal
      readonly property bool darkTheme: Commons.Color.popups.background.hslLightness < 0.5
      anchors.centerIn: parent
      width: window.vertical ? parent.width : parent.width + grow
      height: window.vertical ? parent.height + grow : parent.height
      radius: Math.round(window.slotSize * 0.36)
      color: darkTheme ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.26)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, darkTheme ? 0.22 : 0.5)
      // Reflet en haut, comme le verre Liquid Glass.
      Rectangle {
        anchors.fill: parent; anchors.margins: 1
        radius: parent.radius - 1
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, glass.darkTheme ? 0.08 : 0.18) }
          GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
        }
      }
    }

    Grid {
      id: slots
      anchors.centerIn: parent
      columns: window.vertical ? 1 : appRepeater.count + 3

      AppsSlot {}

      Repeater {
        id: appRepeater
        model: window.dock ? window.dock.itemModel : null

        delegate: AppSlot {}
      }

      StackSlot { id: stackSlot }
      TrashSlot {}
    }
  }

  component Slot: Item {
    id: slot

    // Only the dragged icon is lifted while a drag is on; none of the others
    // pop as it passes over them.
    property bool hovered: mouse.containsMouse && !window.hoverStale && !window.dragging
    property bool pressed: mouse.pressed
    property alias mouse: mouse

    width: window.slotSize
    height: window.slotSize

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    }
  }

  component AppsSlot: Slot {
    id: appsSlot

    property real displayedShift: window.insertIndex >= 0 ? -window.slotSize / 2 : 0

    Behavior on displayedShift {
      enabled: window.animateShifts
      NumberAnimation { duration: Style.duration(150); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }

    transform: Translate {
      x: window.vertical ? 0 : appsSlot.displayedShift + window.waveShift(0)
      y: window.vertical ? appsSlot.displayedShift + window.waveShift(0) : 0
    }

    mouse.onClicked: function(event) {
      if (event.button === Qt.RightButton) {
        window.openSettingsMenu(appsSlot)
        return
      }
      window.closeMenu()
      if (window.dock) window.dock.openApps()
    }

    // A grid of app squares reads as "all apps" in any icon theme. Drawn
    // rather than taken from a font, so its edges stay crisp on the
    // transparent dock and it fills its slot like the app icons beside it.
    Item {
      x: window.iconInset
      y: window.iconInset
      width: window.iconSize
      height: window.iconSize
      scale: window.waveScale(window.slotCenter(0))
      transformOrigin: window.popOrigin

      Grid {
        readonly property int square: Math.round(window.iconSize * 0.22)

        anchors.centerIn: parent
        columns: 3
        spacing: Math.round(window.iconSize * 0.1)

        Repeater {
          model: 9

          delegate: Rectangle {
            width: parent.square
            height: parent.square
            radius: Math.max(1, Math.round(parent.square * 0.2))
            color: Commons.Color.bar.text
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- Corbeille
  // Comme sur macOS : séparateur, icône vide/pleine du thème d'icônes, clic =
  // ouvrir la corbeille dans Fichiers, fichiers glissés dessus = mis à la corbeille
  // (gio trash, réversible). Clic droit = vider, après confirmation (2ᵉ clic droit).
  component TrashSlot: Slot {
    id: trashSlot
    readonly property int slotIndex: appRepeater.count + 2
    property bool full: false
    property bool armed: false        // premier clic droit : « encore une fois pour vider »
    property bool dropHover: false

    Process {
      id: trashProbe
      command: ["sh", "-c", "find \"$HOME/.local/share/Trash/files\" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null"]
      stdout: StdioCollector { onStreamFinished: trashSlot.full = text.trim() !== "" }
    }
    Timer { interval: 8000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!trashProbe.running) trashProbe.running = true }
    Timer { id: disarm; interval: 3000; onTriggered: trashSlot.armed = false }
    function refreshSoon() { refresh.restart() }
    Timer { id: refresh; interval: 700; onTriggered: if (!trashProbe.running) trashProbe.running = true }

    mouse.onClicked: function(event) {
      window.closeMenu()
      if (event.button === Qt.RightButton) {
        if (!trashSlot.full) return
        if (!trashSlot.armed) { trashSlot.armed = true; disarm.restart(); return }
        trashSlot.armed = false
        Quickshell.execDetached(["gio", "trash", "--empty"])
        trashSlot.refreshSoon()
        return
      }
      Quickshell.execDetached(["nautilus", "trash:///"])
    }

    DropArea {
      anchors.fill: parent
      keys: ["text/uri-list"]
      onEntered: trashSlot.dropHover = true
      onExited: trashSlot.dropHover = false
      onDropped: function(drop) {
        trashSlot.dropHover = false
        var argv = ["gio", "trash", "--"]
        for (var i = 0; i < drop.urls.length; i++) {
          var u = String(drop.urls[i])
          if (u.indexOf("file://") === 0) argv.push(decodeURIComponent(u.slice(7)))
        }
        if (argv.length > 3) { Quickshell.execDetached(argv); trashSlot.refreshSoon() }
        drop.accept()
      }
    }

    // Le séparateur est porté par la pile Téléchargements (un seul, comme macOS).
    Rectangle {
      visible: window.vertical
      width: 1
      height: window.iconSize * 0.72
      anchors.verticalCenter: parent.verticalCenter
      x: window.waveShift(trashSlot.slotIndex) - window.waveExtra(trashSlot.slotIndex) / 2
      color: Commons.Color.bar.text
      opacity: 0.22
    }

    Image {
      x: window.iconInset
      y: window.iconInset
      width: window.iconSize
      height: window.iconSize
      sourceSize: Qt.size(window.iconSize * 2, window.iconSize * 2)
      source: Quickshell.iconPath(trashSlot.full ? "user-trash-full" : "user-trash", "user-trash")
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      mipmap: true
      transform: Translate {
        x: window.vertical ? 0 : window.waveShift(trashSlot.slotIndex)
        y: window.vertical ? window.waveShift(trashSlot.slotIndex) : 0
      }
      scale: (trashSlot.dropHover ? 1.15 : 1) * window.waveScale(window.slotCenter(trashSlot.slotIndex))
      transformOrigin: window.popOrigin
    }

    // Bulle « Vider la corbeille ? » après un premier clic droit.
    Rectangle {
      visible: trashSlot.armed
      anchors.horizontalCenter: parent.horizontalCenter
      y: window.position === "top" ? parent.height + 6 : -height - 6
      width: armedText.implicitWidth + 18
      height: armedText.implicitHeight + 10
      radius: height / 2
      color: Commons.Color.popups.background
      border.width: 1
      border.color: Commons.Color.popups.border
      Text {
        id: armedText
        anchors.centerIn: parent
        text: "Clic droit à nouveau pour vider"
        font.pixelSize: Style.font.body
        color: Commons.Color.popups.text
      }
    }
  }

  // ------------------------------------------------------- Téléchargements
  // Pile façon macOS à gauche de la corbeille : l'icône montre le dossier, un
  // clic déploie les fichiers les plus récents en éventail au-dessus du dock.
  component StackSlot: Slot {
    id: stack
    readonly property int slotIndex: appRepeater.count + 1
    visible: !window.vertical

    mouse.onClicked: function(event) {
      if (event.button === Qt.RightButton) {
        window.closeMenu()
        Quickshell.execDetached(["xdg-open", window.downloadsDir])
        return
      }
      var wasOpen = window.stackOpen
      window.closeMenu()
      if (!wasOpen) { window.menuSlot = stack; window.refreshDownloads(); window.stackOpen = true }
    }

    // Séparateur entre les apps et les piles, comme sur macOS.
    Rectangle {
      width: 1
      height: window.iconSize * 0.72
      anchors.verticalCenter: parent.verticalCenter
      x: window.waveShift(stack.slotIndex) - window.waveExtra(stack.slotIndex) / 2
      color: Commons.Color.bar.text
      opacity: 0.22
    }

    Item {
      x: window.iconInset
      y: window.iconInset
      width: window.iconSize
      height: window.iconSize
      transform: Translate { x: window.waveShift(stack.slotIndex) }
      scale: (window.stackOpen ? 0.92 : 1) * window.waveScale(window.slotCenter(stack.slotIndex))
      transformOrigin: window.popOrigin
      Behavior on scale { enabled: window.waveStrength <= 0; NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
      // Deux fichiers récents empilés derrière le dossier quand il y en a.
      Repeater {
        model: window.downloads.slice(0, 2).reverse()
        Image {
          required property var modelData
          required property int index
          width: parent.width * 0.62; height: width
          x: parent.width * 0.19 + (index === 0 ? -3 : 3); y: -2 - index * 3
          rotation: index === 0 ? -8 : 6
          sourceSize: Qt.size(64, 64)
          source: window.fileIcon(modelData)
          fillMode: Image.PreserveAspectFit
          asynchronous: true; smooth: true; mipmap: true
        }
      }
      Image {
        anchors.fill: parent
        sourceSize: Qt.size(window.iconSize * 2, window.iconSize * 2)
        source: Quickshell.iconPath("folder-download", "folder")
        fillMode: Image.PreserveAspectFit
        asynchronous: true; smooth: true; mipmap: true
      }
    }
  }

  readonly property string downloadsDir: (Quickshell.env("XDG_DOWNLOAD_DIR") || (Quickshell.env("HOME") + "/Downloads"))
  // [{ path, name, mime }] du plus récent au plus ancien (10 au plus).
  property var downloads: []
  Process {
    id: downloadsProc
    command: ["sh", "-c", "d=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -d \"$d\" ] || d=\"$HOME/Downloads\"; ls -1At \"$d\" 2>/dev/null | grep -v '^\\.' | head -10 | while IFS= read -r f; do printf '%s\\t%s\\n' \"$d/$f\" \"$(file --mime-type -b \"$d/$f\" 2>/dev/null)\"; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var rows = text.split("\n").filter(function(l) { return l.length > 0 })
        window.downloads = rows.map(function(l) {
          var parts = l.split("\t")
          var path = parts[0]
          return { path: path, name: path.slice(path.lastIndexOf("/") + 1), mime: parts[1] || "" }
        })
      }
    }
  }
  function refreshDownloads() { if (!downloadsProc.running) downloadsProc.running = true }
  Timer { interval: 30000; repeat: true; running: window.shown; triggeredOnStart: true; onTriggered: window.refreshDownloads() }
  function fileIcon(f) {
    if (!f) return ""
    if (/^image\/(png|jpe?g|gif|webp|bmp|svg)/.test(f.mime)) return "file://" + encodeURI(f.path)
    if (f.mime === "inode/directory") return Quickshell.iconPath("folder", "folder")
    var name = String(f.mime).replace("/", "-")
    var generic = String(f.mime).split("/")[0] + "-x-generic"
    return Quickshell.iconPath(name, true) || Quickshell.iconPath(generic, true) || Quickshell.iconPath("text-x-generic", "text-x-generic")
  }

  // Éventail : les fichiers montent en arc au-dessus de la pile, le plus
  // récent en bas, le nom dans une pastille à gauche de l'icône.
  Item {
    id: stackFan
    readonly property int rowH: 46
    readonly property int count: window.downloads.length
    visible: window.contentShown && (window.stackOpen || fanOut.running || fanProgress > 0.01)
    property real fanProgress: window.stackOpen ? 1 : 0
    Behavior on fanProgress { NumberAnimation { id: fanOut; duration: window.stackOpen ? 420 : 200; easing.type: window.stackOpen ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.3 } }
    width: 300
    height: Math.max(1, count) * rowH + 48
    x: {
      var c = stackSlot.mapToItem(window.contentItem, stackSlot.width / 2, 0).x + body.x * 0
      return Math.min(window.width - width - window.gap, c - width + window.iconSize / 2 + 30)
    }
    y: body.y - height - window.gap

    Repeater {
      model: window.downloads
      Item {
        id: fanRow
        required property var modelData
        required property int index
        // Courbe de l'éventail : chaque rang s'écarte un peu plus vers la droite.
        readonly property real bend: index * index * 1.6
        readonly property real p: Math.max(0, Math.min(1, stackFan.fanProgress * (1 + stackFan.count * 0.08) - index * 0.08))
        width: stackFan.width
        height: stackFan.rowH
        y: stackFan.height - (index + 1) * stackFan.rowH * p - 6
        opacity: p
        rotation: -index * 1.2 * p
        transformOrigin: Item.BottomRight
        transform: Translate { x: fanRow.bend * fanRow.p }

        Rectangle {
          id: pill
          anchors.right: fileImg.left; anchors.rightMargin: 8
          anchors.verticalCenter: fileImg.verticalCenter
          width: Math.min(200, nameText.implicitWidth + 18)
          height: nameText.implicitHeight + 8
          radius: height / 2
          color: rowMouse.containsMouse ? Commons.Color.accent : Qt.rgba(0.12, 0.12, 0.14, 0.78)
          Text {
            id: nameText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 182)
            elide: Text.ElideMiddle
            textFormat: Text.PlainText
            text: fanRow.modelData.name
            color: "white"
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: Font.Medium
          }
        }
        Image {
          id: fileImg
          anchors.right: parent.right; anchors.rightMargin: 30
          anchors.verticalCenter: parent.verticalCenter
          width: 40; height: 40
          sourceSize: Qt.size(96, 96)
          source: window.fileIcon(fanRow.modelData)
          fillMode: Image.PreserveAspectFit
          asynchronous: true; smooth: true; mipmap: true
          scale: rowMouse.containsMouse ? 1.12 : 1
          Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
        }
        MouseArea {
          id: rowMouse
          anchors.fill: parent
          anchors.leftMargin: parent.width - pill.width - 86
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { window.closeMenu(); Quickshell.execDetached(["xdg-open", fanRow.modelData.path]) }
        }
      }
    }

    // En haut : « Ouvrir dans Fichiers » (ou « Aucun élément » si vide).
    Rectangle {
      anchors.right: parent.right; anchors.rightMargin: 14
      y: stackFan.height - (stackFan.count + 1) * stackFan.rowH * stackFan.fanProgress + 4
      opacity: stackFan.fanProgress
      width: openText.implicitWidth + 22
      height: openText.implicitHeight + 10
      radius: height / 2
      color: openMouse.containsMouse ? Commons.Color.accent : Qt.rgba(0.12, 0.12, 0.14, 0.78)
      border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
      Text {
        id: openText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: stackFan.count > 0 ? "Ouvrir dans Fichiers  ›" : "Aucun élément · Ouvrir  ›"
        color: "white"
        font.family: "Inter"
        font.pixelSize: 12
        font.weight: Font.Medium
      }
      MouseArea {
        id: openMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { window.closeMenu(); Quickshell.execDetached(["xdg-open", window.downloadsDir]) }
      }
    }
  }

  component AppSlot: Slot {
    id: appSlot

    required property int index
    required property string key
    readonly property var modelData: window.dock ? window.dock.itemFor(key) : null
    readonly property bool launching: !!window.dock && window.dock.isLaunching(key)
    readonly property bool lifted: window.dragIndex === index
    property point pressPoint
    property bool dragged: false
    readonly property int windowCount: modelData ? modelData.windows.length : 0
    property real pulse: 1
    onHoveredChanged: window.hoverApp(appSlot, hovered)

    // Slots between where the dragged app was and where it would land step
    // aside to make room; the dragged one follows the pointer.
    readonly property real shift: window.insertIndex >= 0 ? (index >= window.insertIndex ? 1 : -1) * window.slotSize / 2
      : !window.dragging ? 0
      : lifted ? window.dragOffset
      : (window.dragIndex < index && index <= window.dropIndex) ? -window.slotSize
      : (window.dropIndex <= index && index < window.dragIndex) ? window.slotSize
      : 0
    property real displayedShift: shift

    // Only while dragging: once the drop reorders the slots, they are already
    // where they were shown.
    Behavior on displayedShift {
      enabled: window.animateShifts && ((window.dragging && !appSlot.lifted) || window.insertIndex >= 0)
      NumberAnimation { duration: Style.duration(150); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }

    z: lifted ? 1 : 0

    // The slot, and the pointer handling in it, stays where it is; only the
    // icon moves. Reading the pointer through a slot that moves with it would
    // feed each move back into the next.
    function bodyPoint(event) {
      return appSlot.mapToItem(body, event.x, event.y)
    }

    mouse.onPressed: function(event) {
      appSlot.dragged = false
      if (event.button === Qt.LeftButton) appSlot.pressPoint = appSlot.bodyPoint(event)
    }

    mouse.onPositionChanged: function(event) {
      if (!(appSlot.mouse.pressedButtons & Qt.LeftButton)) return
      var point = appSlot.bodyPoint(event)
      var delta = window.vertical ? point.y - appSlot.pressPoint.y : point.x - appSlot.pressPoint.x
      // A press that wanders is a drag in the making, not a click.
      if (Math.hypot(point.x - appSlot.pressPoint.x, point.y - appSlot.pressPoint.y) > Style.space(4)) appSlot.dragged = true
      if (!window.dragging) {
        if (Math.abs(delta) < Style.space(6)) return
        window.closeMenu()
        // The landing slot first: with the dragged slot set and no landing
        // slot yet, every slot before it would count as in between and step
        // aside for a moment.
        window.dropIndex = appSlot.index
        window.dragIndex = appSlot.index
      }
      if (!appSlot.lifted) return
      window.dragOffset = delta
      window.dropIndex = DockModel.dropIndex(appSlot.index, delta, window.slotSize, appRepeater.count)
    }

    mouse.onReleased: function(event) {
      if (!appSlot.lifted) return
      window.dropPoint = appSlot.mapToItem(body, event.x, event.y)
      var from = window.dragIndex
      var to = window.dropIndex
      appSlot.dragged = true
      window.endDrag()
      window.dock.moveItem(from, to)
    }

    mouse.onCanceled: if (appSlot.lifted) window.endDrag()

    mouse.onClicked: function(event) {
      // A drag ends in a release over the app, which is not a click on it.
      if (appSlot.dragged) {
        appSlot.dragged = false
        return
      }
      if (event.button === Qt.RightButton) {
        window.openMenu(appSlot.modelData, appSlot)
        return
      }
      window.closeMenu()
      window.closePreview()
      if (event.button === Qt.MiddleButton) window.dock.launch(appSlot.modelData)
      else window.dock.activate(appSlot.modelData)
    }

    // Running apps are drawn in full, pinned ones that are not running faded,
    // and one that is starting pulses between the two.
    Image {
      x: window.iconInset
      y: window.iconInset
      width: window.iconSize
      height: window.iconSize
      sourceSize: Qt.size(window.iconSize * 2, window.iconSize * 2)
      source: window.dock && appSlot.modelData ? window.dock.iconFor(appSlot.modelData) : ""
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      mipmap: true
      opacity: appSlot.launching ? appSlot.pulse : (appSlot.windowCount > 0 ? 1 : window.idleOpacity)
      transform: Translate {
        x: window.vertical ? 0 : appSlot.displayedShift + (appSlot.lifted ? 0 : window.waveShift(appSlot.index + 1))
        y: window.vertical ? appSlot.displayedShift + (appSlot.lifted ? 0 : window.waveShift(appSlot.index + 1)) : 0
      }
      scale: appSlot.lifted ? window.magnify : window.waveScale(window.slotCenter(appSlot.index + 1))
      transformOrigin: window.popOrigin
    }

    // Séparateur avant les apps ouvertes qui ne sont pas gardées dans le Dock.
    Rectangle {
      visible: appSlot.index === window.firstRecent && !window.vertical
      width: 1
      height: window.iconSize * 0.72
      anchors.verticalCenter: parent.verticalCenter
      x: window.waveShift(appSlot.index + 1) - window.waveExtra(appSlot.index + 1) / 2 + appSlot.displayedShift
      color: Commons.Color.bar.text
      opacity: 0.22
    }

    // Point sous une app ouverte (comme sur macOS).
    Rectangle {
      readonly property real along: window.waveShift(appSlot.index + 1) + appSlot.displayedShift
      visible: appSlot.windowCount > 0
      width: Math.max(4, Math.round(window.iconSize * 0.09))
      height: width
      radius: width / 2
      color: Commons.Color.bar.text
      opacity: 0.75
      x: window.vertical
        ? (window.position === "left" ? 1 : parent.width - width - 1)
        : Math.round((parent.width - width) / 2 + along)
      y: window.vertical
        ? Math.round((parent.height - height) / 2 + along)
        : (window.position === "top" ? 1 : parent.height - height - 1)
    }

    // Pastille rouge façon macOS (notifications non lues), qui suit la vague.
    Rectangle {
      id: badge
      readonly property int count: window.dock ? window.dock.badgeFor(appSlot.key) : 0
      readonly property real s: window.waveScale(window.slotCenter(appSlot.index + 1))
      visible: count > 0 && !appSlot.lifted
      height: Math.round(window.iconSize * 0.4)
      width: Math.max(height, badgeText.implicitWidth + height * 0.5)
      radius: height / 2
      color: "#ff3b30"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.12)
      // Coin haut-droit de l'icône, après grossissement (origine en bas).
      x: window.iconInset + window.iconSize / 2 + (window.iconSize / 2) * s - width * 0.62
         + appSlot.displayedShift + window.waveShift(appSlot.index + 1)
      y: window.iconInset + window.iconSize - window.iconSize * s - height * 0.3
      z: 2
      scale: visible ? 1 : 0.2
      Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
      Text {
        id: badgeText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: badge.count > 99 ? "99+" : String(badge.count)
        color: "white"
        font.family: "Inter"
        font.pixelSize: Math.round(badge.height * 0.62)
        font.weight: Font.DemiBold
      }
    }

    // With animations off it holds still rather than spinning through
    // zero-length steps.
    SequentialAnimation {
      running: appSlot.launching && !Style.reduceMotion
      loops: Animation.Infinite
      onRunningChanged: if (!running) appSlot.pulse = 1

      NumberAnimation { target: appSlot; property: "pulse"; from: 1; to: window.idleOpacity; duration: Style.duration(500); easing.type: Easing.InOutSine }
      NumberAnimation { target: appSlot; property: "pulse"; to: 1; duration: Style.duration(500); easing.type: Easing.InOutSine }
    }
  }

  // ---- Aperçus en direct des fenêtres d'une app (survol du Dock)
  Rectangle {
    id: preview
    readonly property var wins: window.previewItem ? window.previewItem.windows.slice(0, 5) : []
    readonly property real cardH: 104
    visible: window.contentShown && window.previewOpen && wins.length > 0 && !window.menuOpen
    width: previewRow.implicitWidth + 20
    height: previewRow.implicitHeight + 20
    x: window.popupX(window.previewSlot, preview)
    y: window.popupY(window.previewSlot, preview)
    radius: 18
    color: Commons.Color.popups.background
    border.width: 1
    border.color: Commons.Color.popups.border
    // Arrivée en ressort exagéré depuis l'icône.
    scale: visible ? 1 : 0.6
    opacity: visible ? 1 : 0
    transformOrigin: window.popOrigin
    Behavior on scale { enabled: !Style.reduceMotion; SpringAnimation { spring: 4.2; damping: 0.42; epsilon: 0.004 } }
    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on x { enabled: preview.visible && !Style.reduceMotion; SpringAnimation { spring: 4; damping: 0.55 } }

    HoverHandler {
      onHoveredChanged: {
        window.previewHovered = hovered
        if (!hovered) previewCloseTimer.restart()
        else previewCloseTimer.stop()
      }
    }

    Row {
      id: previewRow
      x: 10; y: 10
      spacing: 10
      Repeater {
        model: preview.wins
        delegate: Item {
          id: card
          required property var modelData
          readonly property var tl: modelData.toplevel
          readonly property real aspect: shot.hasContent && shot.sourceSize.height > 0 ? shot.sourceSize.width / shot.sourceSize.height : 1.6
          width: Math.max(96, Math.min(220, preview.cardH * aspect))
          height: preview.cardH + 22
          scale: cardMouse.pressed ? 0.95 : (cardMouse.containsMouse ? 1.03 : 1)
          Behavior on scale { SpringAnimation { spring: 5; damping: 0.45 } }

          ClippingRectangle {
            id: clip
            width: parent.width
            height: preview.cardH
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: cardMouse.containsMouse ? 2 : 1
            border.color: cardMouse.containsMouse ? Commons.Color.accent : Qt.rgba(1, 1, 1, 0.14)
            ScreencopyView {
              id: shot
              anchors.fill: parent
              captureSource: preview.visible ? card.tl : null
              live: true
              constraintSize: Qt.size(440, 220)
            }
            Image {
              anchors.centerIn: parent
              visible: !shot.hasContent
              width: 40; height: 40
              sourceSize: Qt.size(80, 80)
              source: window.dock && window.previewItem ? window.dock.iconFor(window.previewItem) : ""
            }
          }
          Text {
            anchors.bottom: parent.bottom
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: (card.modelData.minimized ? "◆ " : "") + (card.tl && card.tl.title ? card.tl.title : "")
            font.family: "Inter"; font.pixelSize: Mac.font.subheadline
            color: Commons.Color.popups.text
            opacity: card.tl && card.tl.activated ? 1 : 0.75
          }
          MouseArea {
            id: cardMouse
            anchors.fill: clip
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: function(ev) {
              if (ev.button === Qt.MiddleButton) { if (card.tl) card.tl.close(); return }
              window.closePreview()
              window.dock.bringForward(card.modelData)
            }
          }
          // × rouge au survol pour fermer la fenêtre, comme DockDoor.
          Rectangle {
            x: -5; y: -5
            width: 18; height: 18; radius: 9
            color: closeMouse.containsMouse ? Mac.window.red : Qt.rgba(0.12, 0.12, 0.14, 0.9)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.3)
            opacity: cardMouse.containsMouse || closeMouse.containsMouse ? 1 : 0
            scale: opacity > 0 ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: 100 } }
            Behavior on scale { SpringAnimation { spring: 6; damping: 0.4 } }
            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 9; font.weight: Font.Bold; color: "white" }
            MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (card.tl) card.tl.close() }
          }
        }
      }
    }
  }

  // Menu contextuel façon macOS (lignes de 22 pt, texte 13 pt, coches à gauche) :
  // fenêtres ouvertes, Options ▸, Afficher toutes les fenêtres, Masquer, Quitter
  // (⌥ → Forcer à quitter). L'élément choisi clignote avant la fermeture.
  readonly property var menuRows: {
    var rows = []
    if (window.settingsMenu) {
      var pos = [["top", "En haut"], ["bottom", "En bas"], ["left", T.t("À gauche")], ["right", T.t("À droite")]]
      rows.push({ kind: "header", text: "Position à l'écran" })
      for (var p = 0; p < pos.length; p++)
        rows.push({ text: pos[p][1], checked: window.position === pos[p][0], indent: true, act: "pos:" + pos[p][0] })
      rows.push({ kind: "sep" })
      rows.push({ text: "Masquer automatiquement le Dock", checked: window.autohide, act: "autohide", shortcut: "⌥⌘D" })
      rows.push({ text: "Réglages du Dock…", act: "dock-settings" })
      return rows
    }
    var item = window.menuItem
    if (!item || !window.dock) return rows
    var hasEntry = !!window.dock.entryFor(item)
    var wins = item.windows || []
    for (var i = 0; i < wins.length; i++) {
      var t = wins[i].toplevel
      rows.push({ text: (t && t.title) ? t.title : String(item.key), checked: !!(t && t.activated),
                  diamond: wins[i].minimized, act: "win:" + i })
    }
    if (wins.length > 0) rows.push({ kind: "sep" })
    if (hasEntry && wins.length > 0) rows.push({ text: "Nouvelle fenêtre", act: "new" })
    if (hasEntry) {
      rows.push({ text: "Options", chevron: true, open: window.optionsOpen, act: "options", keep: true })
      if (window.optionsOpen) {
        rows.push({ text: "Garder dans le Dock", checked: !!item.pinned, indent: true, act: "pin" })
        rows.push({ text: "Ouvrir à la connexion", checked: window.loginItem, indent: true, act: "login" })
        rows.push({ text: "Afficher dans le Finder", indent: true, act: "finder" })
      }
      rows.push({ kind: "sep" })
    }
    if (wins.length > 0) {
      rows.push({ text: "Afficher toutes les fenêtres", act: "expose" })
      rows.push({ text: "Masquer", act: "hide", shortcut: "⌘H" })
      rows.push(window.altHeld ? { text: "Forcer à quitter", act: "force", danger: true, shortcut: "⌥⌘⎋" }
                               : { text: "Quitter", act: "quit", shortcut: "⌘Q" })
    } else if (hasEntry) {
      rows.push({ text: T.t("Ouvrir"), act: "open" })
    }
    if (rows.length > 0 && rows[rows.length - 1].kind === "sep") rows.pop()
    return rows
  }

  function runMenuAction(act) {
    var item = window.menuItem
    var wins = item ? item.windows : []
    var addr = wins.length > 0 ? String(wins[0].address || "") : ""
    if (addr && addr.indexOf("0x") !== 0) addr = "0x" + addr
    if (act.indexOf("pos:") === 0) Util.execDetached("omarchy-dock position " + act.slice(4))
    else if (act === "autohide") Util.execDetached("omarchy-dock autohide " + (window.autohide ? "off" : "on"))
    else if (act === "dock-settings") Quickshell.execDetached(["omarchy-shell", "shell", "summon", "liquid-glass.settings", JSON.stringify({ page: "desktop" })])
    else if (act.indexOf("win:") === 0) { var w = wins[parseInt(act.slice(4))]; if (w) window.dock.bringForward(w) }
    else if (act === "new" || act === "open") window.dock.launch(item)
    else if (act === "pin") window.dock.setPinned(item.key, !item.pinned)
    else if (act === "login") Quickshell.execDetached(["liquid-glass", "login-item", String(item.key), window.loginItem ? "off" : "on"])
    else if (act === "finder") {
      Quickshell.execDetached(["sh", "-c", "for d in \"$HOME/.local/share/applications\" /usr/local/share/applications /usr/share/applications; do f=\"$d/$1.desktop\"; [ -f \"$f\" ] && exec nautilus --select \"$f\"; done; exec nautilus /usr/share/applications", "sh", String(item.key)])
    }
    else if (act === "expose" && wins.length > 0 && wins[0].toplevel) Quickshell.execDetached(["omarchy-shell", "shell", "summon", "liquid-glass.mission", JSON.stringify({ app: String(wins[0].toplevel.appId) })])
    else if (act === "hide" && addr) Quickshell.execDetached(["liquid-glass", "window", "hide", addr])
    else if (act === "quit") window.dock.quit(item)
    else if (act === "force" && addr) Quickshell.execDetached(["liquid-glass", "window", "force-quit", addr])
  }

  BorderSurface {
    id: menu

    readonly property var item: window.menuItem
    property int blinkIndex: -1
    property bool blinkOn: false
    property string pendingAct: ""

    visible: window.contentShown && (!!item || window.settingsMenu)
    width: Math.max(Mac.menu.minWidth + 20, Math.min(320, menuColumn.implicitWidth)) + padding * 2
    height: menuColumn.implicitHeight + padding * 2
    x: window.popupX(window.menuSlot, menu)
    y: window.popupY(window.menuSlot, menu)
    radius: Mac.menu.radius
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
    padding: Mac.menu.padV

    // Ouverture : petit ressort depuis l'icône, comme les menus de Tahoe.
    scale: visible ? 1 : 0.9
    opacity: visible ? 1 : 0
    transformOrigin: window.position === "top" ? Item.Top : window.position === "left" ? Item.Left : window.position === "right" ? Item.Right : Item.Bottom
    Behavior on scale { enabled: !Style.reduceMotion; SpringAnimation { spring: 5; damping: 0.5; epsilon: 0.005 } }

    function choose(index, row) {
      if (row.keep) { window.runMenuAction(row.act); return }
      menu.pendingAct = row.act
      menu.blinkIndex = index
      blink.restart()
    }

    // Clignotement de l'élément choisi (éteint, allumé) puis action et fermeture.
    SequentialAnimation {
      id: blink
      PropertyAction { target: menu; property: "blinkOn"; value: false }
      PauseAnimation { duration: 60 }
      PropertyAction { target: menu; property: "blinkOn"; value: true }
      PauseAnimation { duration: 70 }
      ScriptAction {
        script: {
          var act = menu.pendingAct
          menu.blinkIndex = -1
          menu.pendingAct = ""
          window.runMenuAction(act)
          window.closeMenu()
        }
      }
    }

    Column {
      id: menuColumn
      x: menu.contentLeftInset
      y: menu.contentTopInset
      width: menu.width - menu.contentLeftInset - menu.contentRightInset

      Repeater {
        model: window.menuRows
        delegate: Item {
          id: mrow
          required property var modelData
          required property int index
          readonly property string kind: modelData.kind || "item"
          readonly property bool blinking: menu.blinkIndex === index
          readonly property bool hot: kind === "item" && (blinking ? menu.blinkOn : (menu.blinkIndex < 0 && rowMouse.containsMouse))
          width: menuColumn.width
          implicitWidth: Mac.menu.checkColumn + (modelData.indent ? 14 : 0) + rowText.implicitWidth + (rowShortcut.visible ? rowShortcut.implicitWidth + 24 : 0) + 28
          height: kind === "sep" ? Mac.menu.separatorMargin * 2 + 1 : Mac.menu.row

          Rectangle {
            visible: mrow.kind === "sep"
            anchors.verticalCenter: parent.verticalCenter
            x: Mac.menu.inset + 4; width: parent.width - x * 2; height: 1
            color: Commons.Color.popups.text; opacity: 0.12
          }
          Rectangle {
            visible: mrow.kind === "item"
            anchors.fill: parent
            anchors.leftMargin: Mac.menu.inset - Mac.menu.padV
            anchors.rightMargin: Mac.menu.inset - Mac.menu.padV
            radius: Mac.menu.selRadius
            color: mrow.modelData.danger ? "#ff3b30" : Commons.Color.accent
            opacity: mrow.hot ? 0.92 : 0
          }
          // Colonne de coche (✓ fenêtre active / option cochée, ◆ fenêtre réduite).
          Text {
            visible: mrow.kind === "item" && (!!mrow.modelData.checked || !!mrow.modelData.diamond)
            x: Mac.menu.inset + 2 + (mrow.modelData.indent ? 14 : 0)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: mrow.modelData.checked ? "✓" : "◆"
            font.family: "Inter"; font.pixelSize: mrow.modelData.checked ? 12 : 8
            color: mrow.hot ? "#ffffff" : Commons.Color.popups.text
          }
          Text {
            id: rowText
            x: mrow.kind === "header" ? Mac.menu.inset + 4 : Mac.menu.checkColumn + 2 + (mrow.modelData.indent ? 14 : 0)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - x - (rowShortcut.visible ? rowShortcut.implicitWidth + 22 : 14))
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: mrow.modelData.text || ""
            font.family: "Inter"
            font.pixelSize: mrow.kind === "header" ? Mac.font.subheadline : Mac.font.body
            font.weight: mrow.kind === "header" ? Font.DemiBold : Font.Normal
            font.letterSpacing: Mac.tracking(Mac.font.body)
            color: mrow.hot ? "#ffffff" : (mrow.modelData.danger ? "#ff453a" : Commons.Color.popups.text)
            opacity: mrow.kind === "header" ? Mac.label.secondary : 1
          }
          Text {
            id: rowShortcut
            visible: mrow.kind === "item" && (!!mrow.modelData.shortcut || !!mrow.modelData.chevron)
            anchors.right: parent.right; anchors.rightMargin: Mac.menu.padRight - Mac.menu.padV + 4
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: mrow.modelData.chevron ? "›" : (mrow.modelData.shortcut || "")
            font.family: "Inter"; font.pixelSize: mrow.modelData.chevron ? 15 : Mac.font.body
            color: mrow.hot ? "#ffffff" : Commons.Color.popups.text
            opacity: mrow.hot ? 0.9 : Mac.label.secondary
            rotation: mrow.modelData.chevron && mrow.modelData.open ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: mrow.kind === "item"
            hoverEnabled: true
            onClicked: menu.choose(mrow.index, mrow.modelData)
          }
        }
      }
    }
  }
}
