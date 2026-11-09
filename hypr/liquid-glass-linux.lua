-- ============================================================================
-- Liquid Glass — profil « Linux » (⌘⇧Espace / `liquid-glass profile linux`).
--
-- Chargé par liquid-glass.lua À LA PLACE de tout le réglage macOS quand
-- profile = "linux" : rien des fenêtres Mac (barres de titre, flottant, ressorts
-- Tahoe, raccourcis ⌘) ni des menus d'Omarchy : chaque style (Blanc, Sombre,
-- Jouet, Violet, Expressive, Windows, Mono, Forêt) a son lanceur et ses réglages.
-- Base : tiling dwindle, espaces 5/8, bordure 2 px en dégradé, animations
-- back_out ; le plugin liquid-glass.linux ajuste coins/bordures/ombres par style.
-- ============================================================================

local v = ...
v = type(v) == "table" and v or {}

hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 8,
    border_size = 2,
    layout = "dwindle",
  },
  decoration = {
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    dim_inactive = false,
    shadow = { enabled = false },
    blur = { enabled = true, size = 4, passes = 2, new_optimizations = true, xray = false },
  },
  dwindle = { preserve_split = true },
})

-- Animations à rebond des dotfiles (back_out : petit dépassement en glissant).
hl.curve("back_out", { type = "bezier", points = { { 0.34, 1.56 }, { 0.64, 1 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.config({ animations = { enabled = true } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "back_out", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "back_out", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "back_out", style = "slide" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "back_out", style = "slide top" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "easeOutQuint" })

-- Le fond d'écran reste net derrière les panneaux du bureau ; la barre est opaque.
hl.layer_rule({
  match = { namespace = "^(omarchy-launcher|omarchy-keyboard-panel|omarchy-osd)$" },
  blur = true,
  ignore_alpha = 0.05,
})

-- Souris et trackpad ([input]) : mêmes réglages que le profil Mac.
if type(v.input) == "table" then hl.config({ input = v.input }) end

-- ⌘⇧Espace : sélecteur de bureaux (Mac, Omarchy, Windows, Mono, Forêt, Blanc…).
o.rebind("SUPER + SHIFT + SPACE", "Bureaux (Mac, Omarchy, Windows, Mono, Forêt…)", "liquid-glass profile pick")
o.rebind("SUPER + SHIFT + CTRL + SPACE", "Bureaux", "liquid-glass profile pick")

-- Plus aucune interface d'Omarchy sur le bureau Linux : chaque style a son
-- lanceur, ses réglages et son menu d'alimentation (plugin liquid-glass.linux).
--   ⌘Espace     lanceur du style (menu Démarrer en style Windows)
--   ⌘⌥Espace    Réglages (les mêmes partout, page du style en tête ; Paramètres en style Windows)
--   ⌘Échap      Réglages aussi (comme sur Mac)
--   ⌘⇧Échap     alimentation (session caelestia, batterie forêt, menu Démarrer…)
--   ⌘K          feuille des raccourcis, aux couleurs du style
--   ⌃⌘T         teinte suivante du style (violet nuit → aube → rose, Windows clair/sombre…)
local LG = "omarchy-shell liquid-glass.linux "
o.rebind("SUPER + SPACE", "Lanceur du bureau", LG .. "launcher")
o.rebind("SUPER + SHIFT + code:201", "Lanceur du bureau", LG .. "launcher")
o.rebind("SUPER + ALT + SPACE", "Réglages", LG .. "settings")
o.rebind("SUPER + ESCAPE", "Réglages", LG .. "settings")
o.rebind("SUPER + SHIFT + ESCAPE", "Alimentation", LG .. "power")
o.rebind("SUPER + CTRL + O", "Réglages du bureau", LG .. "menu home")
o.rebind("SUPER + CTRL + H", "Réglages du bureau", LG .. "menu home")
o.rebind("SUPER + CTRL + C", "Capture d'écran", "omarchy-capture-screenshot")
o.rebind("SUPER + CTRL + T", "Teinte suivante du bureau", "liquid-glass profile tone")
o.rebind("SUPER + K", "Raccourcis du bureau", LG .. "keys")

-- ⌃⌘Espace / ⌃⌘W : carrousel de fonds façon Serpantinum (à la place du sélecteur Omarchy).
o.rebind("SUPER + CTRL + SPACE", "Fonds d'écran (carrousel)", LG .. "wallpapers")
o.rebind("SUPER + CTRL + W", "Fonds d'écran (carrousel)", LG .. "wallpapers")

-- ⌃⌘M : menu des rices (pages de 1 à 13 terminaux animés, scène par scène).
-- ⌃⌘⇧M : page suivante sans passer par le menu.
o.rebind("SUPER + CTRL + M", "Rice au hasard (1 à 13 terminaux)", "liquid-glass rice random")
o.rebind("SUPER + CTRL + SHIFT + M", "Fermer le rice", "liquid-glass rice stop")
o.rebind("SUPER + CTRL + ALT + M", "Rice : pages à composer", LG .. "rice")

-- Paramètres (style Windows) : vraie fenêtre, flottante et centrée.
hl.window_rule({
  name = "liquid-glass-win-settings",
  match = { title = "^Paramètres$", class = "^(org\\.quickshell|quickshell)$" },
  float = true,
  size = "980 640",
  center = true,
})

-- Zoom : toile du style Infini (la toile et ses fenêtres), loupe d'Hyprland ailleurs.
--   ⌘ + molette / deux doigts   zoom au pointeur (Infini) ; bureau voisin sinon
--   ⌘⌃Z / ⌘⌃⇧Z / ⌘⌃⌥Z         zoom avant / arrière / 100 %
--   ⌘⌃+ / ⌘⌃−                  zoom avant / arrière (pavé numérique aussi)
--   ⌘ + pincer (deux doigts)    zoom avant / arrière
o.rebind("SUPER + mouse_up", "Zoom avant (toile Infini) / bureau précédent", LG .. "wheel up")
o.rebind("SUPER + mouse_down", "Zoom arrière (toile Infini) / bureau suivant", LG .. "wheel down")
o.rebind("SUPER + CTRL + Z", "Zoom avant", LG .. "zoom in")
o.rebind("SUPER + CTRL + SHIFT + Z", "Zoom arrière", LG .. "zoom out")
o.rebind("SUPER + CTRL + ALT + Z", "Zoom à 100 %", LG .. "zoom reset")
for _, k in ipairs({ "equal", "plus", "KP_Add" }) do o.rebind("SUPER + CTRL + " .. k, "Zoom avant", LG .. "zoom in") end
for _, k in ipairs({ "minus", "KP_Subtract" }) do o.rebind("SUPER + CTRL + " .. k, "Zoom arrière", LG .. "zoom out") end
pcall(function()
  hl.gesture({ fingers = 2, direction = "pinchout", mods = "SUPER", action = function() hl.exec_cmd(LG .. "zoom in") end })
  hl.gesture({ fingers = 2, direction = "pinchin", mods = "SUPER", action = function() hl.exec_cmd(LG .. "zoom out") end })
end)
