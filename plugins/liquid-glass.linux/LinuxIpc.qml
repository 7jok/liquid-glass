import QtQuick
import qs.Commons

// Commandes IPC du bureau Linux :
//   omarchy-shell liquid-glass.linux wallpapers   → carrousel de fonds (⌃⌘Espace)
//   omarchy-shell liquid-glass.linux closeWallpapers
//   omarchy-shell liquid-glass.linux resetLayout  → widgets à leur place d'origine
//   omarchy-shell liquid-glass.linux palette      → couleurs Material You actuelles
//   omarchy-shell liquid-glass.linux launcher     → lanceur du style / menu Démarrer (⌘Espace)
//   omarchy-shell liquid-glass.linux menu [page]  → réglages du style / Paramètres Windows (⌘⌥Espace)
//   omarchy-shell liquid-glass.linux panel <nom>  → volet de la barre (quick, calendar, dashboard, music…)
//   omarchy-shell liquid-glass.linux keys         → feuille des raccourcis (⌘K)
//   omarchy-shell liquid-glass.linux power        → alimentation du style (⌘Échap)
//   omarchy-shell liquid-glass.linux rice         → menu des terminaux animés (⌃⌘M)
//   omarchy-shell liquid-glass.linux zoom in|out|reset → zoom de la toile (Infini) ou loupe (⌘⌃Z…)
//   omarchy-shell liquid-glass.linux wheel up|down   → ⌘ + molette : zoom (Infini) ou bureau voisin
//   omarchy-shell liquid-glass.linux closeAll
Item {
  id: root
  property var service: null
  ShellIpc {
    target: "liquid-glass.linux"
    function wallpapers(): void { if (root.service) root.service.wallsOpen = !root.service.wallsOpen }
    function closeWallpapers(): void { if (root.service) root.service.wallsOpen = false }
    function launcher(): void { if (root.service) root.service.toggleLauncher() }
    function menu(page: string): void { if (root.service) root.service.toggleMenu(page) }
    // Réglages communs (page du style) ; Paramètres façon Windows 11 en style Windows.
    function settings(): void { if (root.service) root.service.openSettings() }
    function panel(name: string): void { if (root.service) root.service.togglePanel(name) }
    function keys(): void { if (root.service) root.service.toggleKeys() }
    function rice(): void { if (root.service) root.service.togglePanel("rice") }
    function power(): void { if (root.service) root.service.powerMenu() }
    // Zoom (toile Infini, loupe ailleurs) : in | out | reset ; molette : up | down
    function zoom(dir: string): void { if (root.service) root.service.zoom(dir) }
    function wheel(dir: string): void { if (root.service) root.service.wheel(dir) }
    function closeAll(): void { if (root.service) { root.service.closeAll(); root.service.menuOpen = false } }
    function resetLayout(): void { if (root.service) root.service.resetLayout() }
    function palette(): string {
      var s = root.service
      return s ? JSON.stringify({ bg: s.bgPath, scheme: s.scheme, primary: String(s.primary), surface: String(s.surfaceMid) }) : "{}"
    }
  }
}
