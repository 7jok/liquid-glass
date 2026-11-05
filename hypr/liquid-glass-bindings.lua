-- ============================================================================
-- Liquid Glass — raccourcis façon macOS (SUPER = ⌘).
-- Chargé à la fin de liquid-glass.lua, donc après les raccourcis Omarchy :
-- chaque remplacement « hl.unbind » puis « o.bind » est listé ci-dessous avec
-- ce qu'il remplaçait et où l'ancienne action a été déplacée.
--
-- Pour revenir aux raccourcis Omarchy : commenter require("liquid-glass-bindings")
-- dans liquid-glass.lua (ou mettre keybindings = false dans config.toml).
-- ============================================================================

local function shell(cmd) return "omarchy-shell " .. cmd end

local function rebind(keys, description, action)
  hl.unbind(keys)
  o.bind(keys, description, action)
end

-- ⌘Espace : Spotlight            (était : menu Omarchy → déplacé sur ⌘⌥Espace)
-- ⌘⌥Espace : menu Omarchy        (était : grille d'apps → toujours dans le dock et Spotlight)
rebind("SUPER + SPACE", "Spotlight", shell("shell toggle liquid-glass.spotlight"))
rebind("SUPER + ALT + SPACE", "Omarchy menu", { menu = "root" })

-- ⌘Q : quitter l'application (toutes ses fenêtres)   (était : fermer la fenêtre)
-- ⌘W : fermer la fenêtre — inchangé.
local function quit_app()
  local active = hl.get_active_window()
  if not active then return end
  for _, window in ipairs(hl.get_windows()) do
    if window.class == active.class then
      hl.dispatch(hl.dsp.window.close({ window = "address:" .. window.address }))
    end
  end
end
rebind("SUPER + Q", "Quit application", quit_app)

-- ⌘Tab / ⌘⇧Tab : sélecteur d'apps   (était : bureau suivant / précédent → ⌘← / ⌘→)
-- Relâcher SUPER valide ; l'overlay capte la touche.
rebind("SUPER + TAB", "App switcher", shell("shell summon liquid-glass.switcher '{\"dir\":1}'"))
rebind("SUPER + SHIFT + TAB", "App switcher (previous)", shell("shell summon liquid-glass.switcher '{\"dir\":-1}'"))

-- ⌘↑ : Mission Control             (était : focus fenêtre du dessus → ⌘⌃↑)
-- ⌘⌃↑ / ⌘⌃↓ : focus haut / bas     (libres auparavant)
rebind("SUPER + UP", "Mission Control", shell("shell toggle liquid-glass.mission"))
o.bind("SUPER + CTRL + UP", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + CTRL + DOWN", "Focus on below window", hl.dsp.focus({ direction = "d" }))

-- ⌘⇧3 / ⌘⇧4 / ⌘⇧5 : captures plein écran / zone / menu de capture
-- (étaient : déplacer la fenêtre vers le bureau 3/4/5 → ⌘⌃⇧<chiffre>, tous les bureaux)
-- Les chiffres sont liés par code de touche (code:10 = 1 … code:19 = 0), comme Omarchy.
rebind("SUPER + SHIFT + code:12", "Screenshot (full screen)", "omarchy capture screenshot fullscreen")
rebind("SUPER + SHIFT + code:13", "Screenshot (region)", "omarchy capture screenshot region")
rebind("SUPER + SHIFT + code:14", "Capture menu", { menu = "capture" })
for workspace = 1, 10 do
  o.bind("SUPER + CTRL + SHIFT + code:" .. tostring(workspace + 9), "Move window to workspace " .. workspace,
    o.workspaces.move_window(workspace))
end

-- ⌘K : aide-mémoire des raccourcis Liquid Glass   (était : raccourcis Omarchy → ⌘⇧K)
rebind("SUPER + K", "Shortcut cheat sheet", shell("liquid-glass.cheatsheet toggle"))
o.bind("SUPER + SHIFT + K", "Omarchy keybindings", "omarchy-menu-keybindings")

-- ⌘⇧L : clair / sombre ; ⌃⌘Q : verrouiller ; ⌘⌥M : paroles en karaoké (touches libres)
o.bind("SUPER + SHIFT + L", "Toggle light / dark", "liquid-glass mode toggle")
o.bind("SUPER + CTRL + Q", "Lock screen", "omarchy-system-lock")
o.bind("SUPER + ALT + M", "Lyrics karaoke", shell("liquid-glass.spotify karaoke"))
o.bind("SUPER + F3", "Show desktop", "liquid-glass show-desktop")

-- Pavé tactile : 4 doigts vers le haut = Mission Control, vers le bas = fermer.
hl.gesture({ fingers = 4, direction = "up", action = function()
  hl.exec_cmd(shell("shell summon liquid-glass.mission ''"))
end })
hl.gesture({ fingers = 4, direction = "down", action = function()
  hl.exec_cmd(shell("shell hide liquid-glass.mission"))
end })
