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
-- ⌘↓ : App Exposé — les fenêtres de l'app active, tous bureaux, + documents récents
--      (était : focus fenêtre du dessous → ⌘⌃↓)
rebind("SUPER + DOWN", "App Exposé", shell("shell toggle liquid-glass.mission '{\"app\":\"active\"}'"))
o.bind("SUPER + CTRL + UP", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + CTRL + DOWN", "Focus on below window", hl.dsp.focus({ direction = "d" }))

-- ⌘⇧3 / ⌘⇧4 / ⌘⇧5 : captures plein écran / zone / menu de capture
-- (étaient : déplacer la fenêtre vers le bureau 3/4/5 → ⌘⌃⇧<chiffre>, tous les bureaux)
-- Les chiffres sont liés par code de touche (code:10 = 1 … code:19 = 0), comme Omarchy.
-- Lancées sans --notify, les captures d'omasnap affichent la vignette flottante en bas
-- à droite pendant 7 s, comme sur Mac (épingler, Modifier ; déjà copiées et enregistrées).
rebind("SUPER + SHIFT + code:12", "Screenshot (full screen)", "omasnap fullscreen")
rebind("SUPER + SHIFT + code:13", "Screenshot (region)", "omasnap region")
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
-- Rice aussi sur le bureau Mac.
o.bind("SUPER + CTRL + M", "Rice au hasard (1 à 13 terminaux)", "liquid-glass rice random")
o.bind("SUPER + CTRL + SHIFT + M", "Fermer le rice", "liquid-glass rice stop")
o.bind("SUPER + ALT + M", "Lyrics karaoke", shell("liquid-glass.spotify karaoke"))
o.bind("SUPER + F3", "Show desktop", "liquid-glass show-desktop")

-- Mosaïque façon macOS Sequoia (menu Fenêtre) : ⌃⌥ ← → ↑ ↓ moitiés, ⌃⌥F remplir,
-- ⌃⌥C centrer, ⌥⌘H masquer les autres, ⌘H masquer l'app (touches libres).
for key, act in pairs({ LEFT = "left", RIGHT = "right", UP = "top", DOWN = "bottom", F = "fill", C = "center" }) do
  o.bind("CTRL + ALT + " .. key, "Window: " .. act, "liquid-glass window " .. act)
end
o.bind("SUPER + H", "Hide application", "liquid-glass window hide")
o.bind("SUPER + ALT + H", "Hide other applications", "liquid-glass window hide-others")

-- ⌘⌥B : En veille (StandBy) — grande horloge + widget, rouge la nuit (touche libre).
o.bind("SUPER + ALT + B", "StandBy", shell("liquid-glass.standby toggle"))

-- ⌥⌘Échap : Forcer à quitter (touche libre ; ⌘Échap reste le menu système Omarchy).
o.bind("SUPER + ALT + ESCAPE", "Force quit applications", shell("shell toggle liquid-glass.forcequit"))

-- Pavé tactile : 4 doigts vers le haut = Mission Control ; vers le bas = App Exposé
-- (ou fermer Mission Control s'il est ouvert, comme sur macOS).
hl.gesture({ fingers = 4, direction = "up", action = function()
  hl.exec_cmd(shell("shell summon liquid-glass.mission ''"))
end })
hl.gesture({ fingers = 4, direction = "down", action = function()
  hl.exec_cmd(shell("shell summon liquid-glass.mission '{\"app\":\"active\"}'"))
end })

-- Touche ⌥ maintenue : les menus du Dock et du menu Pomme révèlent leurs éléments
-- alternatifs (« Forcer à quitter », « Redémarrer » sans confirmation…). Une couche
-- Wayland sans focus clavier ne voit pas les modificateurs : Hyprland écrit donc
-- l'état de ⌥ dans un fichier que le shell surveille. Liaisons transparentes et
-- non consommantes : Alt continue d'arriver normalement aux apps.
local alt_state = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/liquid-glass-alt"
local function set_alt(value)
  local file = io.open(alt_state, "w")
  if file then file:write(value); file:close() end
end
set_alt("0")
for _, key in ipairs({ "Alt_L", "Alt_R" }) do
  hl.bind(key, function() set_alt("1") end,
    { transparent = true, non_consuming = true, ignore_mods = true, description = "Option held" })
  hl.bind(key, function() set_alt("0") end,
    { release = true, transparent = true, non_consuming = true, ignore_mods = true, description = "Option released" })
end
