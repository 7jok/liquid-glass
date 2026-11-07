.pragma library
// ============================================================================
//  Liquid Glass — mesures macOS (design tokens)
//  Source unique : liquid-glass/shared/Mac.js, recopiée dans chaque plugin par
//  scripts/push-tokens.sh (Omarchy refuse les liens symboliques et les imports
//  hors du dossier d'un plugin). Ne pas modifier les copies.
//
//  Unité : 1 pt macOS = 1 px logique Qt (Hyprland applique le scale 1,5).
//  Sources : Apple HIG (Typography, macOS text styles), Apple Design Resources
//  macOS, captures de macOS Sequoia/Tahoe. Repères à ±1–2 pt.
// ============================================================================

// ---- Typographie : styles de texte macOS (taille, graisse, interligne)
var font = {
  largeTitle: 26, title1: 22, title2: 17, title3: 15,
  headline: 13,   // bold
  body: 13,       // texte d'interface standard
  callout: 12, subheadline: 11, footnote: 10, caption1: 10, caption2: 10
}
var lineHeight = {
  largeTitle: 32, title1: 26, title2: 22, title3: 20, headline: 16, body: 16,
  callout: 15, subheadline: 14, footnote: 13, caption1: 13, caption2: 13
}
// Inter paraît un peu plus gros que SF Pro à taille égale : léger tracking
// négatif. Inter Display au-dessus de 20 pt (= SF Pro Display).
function tracking(px) { return px >= 20 ? -0.4 : (px >= 13 ? -0.08 : 0) }
function family(px) { return px >= 20 ? "Inter Display" : "Inter" }

// Opacité des libellés (labelColor, secondary, tertiary, quaternary)
var label = { primary: 0.85, secondary: 0.50, tertiary: 0.26, quaternary: 0.10 }

// ---- Espacements (grille de 4/8 pt)
var space = { xxs: 2, xs: 4, s: 8, m: 12, l: 16, xl: 20, xxl: 24 }

// ---- Barre de menus
var menuBar = { height: 24, titlePad: 10, iconGap: 10, icon: 16, highlightH: 22, highlightRadius: 5 }

// ---- Menus déroulants et contextuels
var menu = { row: 22, padV: 5, inset: 5, selRadius: 5, radius: 10, separatorMargin: 5,
             checkColumn: 20, minWidth: 200, padRight: 14 }

// ---- Fenêtres
var window = { titleBar: 28, toolbar: 52, toolbarCompact: 38, radius: 12,
               light: 12, lightGap: 8, lightInset: 8, lightInsetToolbar: 20,
               red: "#FF5F57", yellow: "#FEBC2E", green: "#28C840",
               redEdge: "#E0443E", yellowEdge: "#DEA123", greenEdge: "#1AAB29",
               inactive: "#C7C7C7", inactiveDark: "#4D4D4D", glyph: 8 }

// ---- Contrôles
var control = { regular: 22, small: 19, mini: 15, large: 28, radius: 6, padH: 14, minWidth: 70,
                field: 24, fieldRadius: 6, focusRing: 3.5,
                switchW: 38, switchH: 22, checkbox: 14, radio: 16, segmented: 24, popup: 22, knob: 20 }

// ---- Barre latérale (Réglages, Finder)
var sidebar = { width: 230, row: 28, icon: 20, iconRadius: 5, selRadius: 6, header: 11, inset: 8 }

// ---- Réglages Système
var settings = { width: 715, groupRadius: 10, row: 40, margin: 20 }

// ---- Dock
var dock = { iconDefault: 48, iconMin: 16, iconMax: 128, dot: 4, dotGap: 2, pad: 5, radius: 18 }

// ---- Icônes d'apps : forme = 824/1024 du cadre, rayon continu ≈ 22,5 % de la forme
var appIcon = { shapeRatio: 0.805, radiusRatio: 0.225 }

// ---- Spotlight
var spotlight = { width: 680, field: 52, fieldFont: 22, row: 36, icon: 28, topRatio: 0.26 }

// ---- Notifications et widgets
var notification = { width: 344, minHeight: 64, radius: 18, icon: 36, margin: 12 }
var widget = { small: 170, gap: 24, radius: 22, pad: 16,
               medium: [364, 170], large: [364, 382], xlarge: [752, 382] }

// ---- Control Center
var controlCenter = { width: 320, cell: 70, gap: 10, round: 48, radius: 22 }

// ---- Alertes, infobulles, HUD
var alert = { width: 260, icon: 64, radius: 14 }
var tooltip = { font: 11, pad: 5, radius: 5, delay: 900 }
var hud = { width: 220, height: 40, radius: 20 }

// ---- Île dynamique (fausse encoche)
var island = { width: 190, height: 32, radius: 16, hoverWidth: 260, hoverHeight: 40,
               openWidth: 420, openHeight: 160, openRadius: 32, top: 4 }

// ---- Animations : macOS « normal » vs Liquid Glass (ressort exagéré, préférence utilisateur)
var motion = { fast: 180, normal: 260, slow: 380,
               springMac: { spring: 4.0, damping: 0.42, mass: 1.0 },
               springLG:  { spring: 3.2, damping: 0.24, mass: 1.0 } }
