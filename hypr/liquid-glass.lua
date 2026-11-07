-- ============================================================================
-- Liquid Glass — apparence Hyprland façon macOS.
--
-- Chargé à la FIN de ~/.config/hypr/hyprland.lua, après les toggles Omarchy,
-- pour que ces réglages passent devant ceux du mode « glassy » (glass.lua).
-- Les valeurs réglables viennent de ~/.config/liquid-glass/hypr-vars.lua, généré
-- par `liquid-glass apply` depuis la config centrale (valeurs par défaut sinon).
-- ============================================================================

local ok, v = pcall(dofile, (os.getenv("HOME") or "") .. "/.config/liquid-glass/hypr-vars.lua")
if not ok or type(v) ~= "table" then v = {} end

local function val(key, default)
  if v[key] == nil then return default end
  return v[key]
end

-- Son du clavier (Mechvibes) sur tous les profils, sans groupe « input » :
-- Hyprland signale les frappes par jetons anonymes (inerte si le lecteur est arrêté).
do
  local here = debug.getinfo(1, "S").source:match("^@(.*/)") or ((os.getenv("HOME") or "") .. "/.config/hypr/")
  local chunk = loadfile(here .. "liquid-glass-keys.lua")
  if chunk then pcall(chunk) end
end

-- Profil « Linux » (⌘⇧Espace) : un autre bureau, sans rien de macOS. Son réglage
-- est dans liquid-glass-linux.lua, chargé à la place de tout ce qui suit.
-- Profil « Omarchy » (⌘⇧Espace → Omarchy) : Omarchy tel qu'il est livré, sans
-- aucun réglage Liquid Glass. Seul ajout : ⌘⇧Espace ouvre le sélecteur de bureaux
-- pour pouvoir revenir (à la place de « masquer la barre »).
if val("profile", "mac") == "omarchy" then
  o.rebind("SUPER + SHIFT + SPACE", "Bureaux (Mac, Windows, Mono, Forêt…)", "liquid-glass profile pick")
  return
end

if val("profile", "mac") == "linux" then
  local here = debug.getinfo(1, "S").source:match("^@(.*/)") or ((os.getenv("HOME") or "") .. "/.config/hypr/")
  local chunk, err = loadfile(here .. "liquid-glass-linux.lua")
  if chunk then
    local ran, run_err = pcall(chunk, v)
    if not ran then hl.exec_cmd("notify-send 'Liquid Glass' " .. o.shell_quote("profil Linux : " .. tostring(run_err))) end
  else
    hl.exec_cmd("notify-send 'Liquid Glass' " .. o.shell_quote("profil Linux : " .. tostring(err)))
  end
  return
end

hl.config({
  general = {
    gaps_in = val("gaps_in", 5),
    gaps_out = val("gaps_out", 10),
    border_size = 1, -- liseré fin ; la couleur vient du thème (blanc translucide)
  },

  decoration = {
    rounding = val("rounding", 16),
    rounding_power = 2.6, -- coins « squircle » plus doux qu'un arc de cercle

    active_opacity = 1.0,
    inactive_opacity = 1.0,
    dim_inactive = false,

    -- Ombre douce et diffuse, décalée vers le bas comme sur macOS.
    shadow = {
      enabled = true,
      range = 36,
      render_power = 3,
      offset = { 0, 10 },
      color = "rgba(00000048)",
      color_inactive = "rgba(00000026)",
    },

    -- Flou prononcé mais dosé pour un iGPU Intel UHD 620.
    blur = {
      enabled = true,
      size = val("blur_size", 7),
      passes = val("blur_passes", 3),
      noise = 0.018,
      contrast = 0.95,
      brightness = 1.0,
      vibrancy = 0.22,
      vibrancy_darkness = 0.2,
      new_optimizations = true,
      xray = false,
      popups = true,
      special = true,
    },
  },
})

-- ---------------------------------------------------------------------------
-- Animations : ressorts (spring) façon macOS.
-- ---------------------------------------------------------------------------
local anim = val("animations", true)
hl.config({ animations = { enabled = anim } })

if anim then
  -- Ressort léger : petit dépassement, s'arrête vite.
  hl.curve("lgSpring", { type = "spring", mass = 1, stiffness = 110, dampening = 15 })
  -- Ressort plus amorti pour les déplacements et les bureaux.
  hl.curve("lgSmooth", { type = "spring", mass = 1, stiffness = 95, dampening = 19 })
  -- Sorties rapides, sans rebond.
  hl.curve("lgOut", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })
  hl.curve("lgEase", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })

  hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, spring = "lgSpring", style = "popin 88%" })
  hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, bezier = "lgOut", style = "popin 92%" })
  hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, spring = "lgSmooth" })
  hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.2, bezier = "lgEase" })
  hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.8, bezier = "lgOut" })
  hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "lgEase" })

  -- Menus, panneaux et Spotlight : léger zoom + fondu.
  hl.animation({ leaf = "layersIn", enabled = true, speed = 3.2, spring = "lgSpring", style = "popin 94%" })
  hl.animation({ leaf = "layersOut", enabled = true, speed = 2.2, bezier = "lgOut", style = "popin 96%" })
  hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2.2, bezier = "lgEase" })
  hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.6, bezier = "lgOut" })

  -- Changement de bureau : glissement horizontal fluide (Spaces).
  hl.animation({ leaf = "workspaces", enabled = true, speed = 4.2, spring = "lgSmooth", style = "slide" })
  hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.5, spring = "lgSmooth", style = "slidevert" })
end

-- ---------------------------------------------------------------------------
-- Transparence des fenêtres : verre discret, le texte reste net.
-- (Navigateurs/vidéo désactivent déjà la transparence côté Omarchy.)
-- ---------------------------------------------------------------------------
local wo = val("window_opacity", { 0.96, 0.9 })
o.window({ tag = "default-opacity" }, { opacity = string.format("%.2f %.2f", wo[1], wo[2]) })
-- Les terminaux dessinent eux-mêmes leur fond en verre (foot.ini du thème).
o.window({ tag = "terminal" }, { opacity = "1.0 1.0" })

-- ---------------------------------------------------------------------------
-- Flou derrière les surfaces du shell que le mode glassy ne couvre pas,
-- et derrière les surfaces Liquid Glass (dock, centre de contrôle, Spotlight…).
-- ---------------------------------------------------------------------------
hl.layer_rule({
  -- Pas les paroles du bureau ni le visualiseur : flouter derrière du texte n'a pas de sens.
  match = { namespace = "^(omarchy-dock|omarchy-launcher|omarchy-lock.*|liquid-glass-(spotlight|mission|switcher|karaoke|lyrics-widget|cheatsheet|settings|widgets|tilemenu)|omarchy-osd)$" },
  blur = true,
  ignore_alpha = 0.05,
})
-- Panneaux du shell (dont le Centre de contrôle, fait de capsules très
-- transparentes) : flou même sous un verre léger, rien entre les capsules.
hl.layer_rule({
  match = { namespace = "^omarchy-keyboard-panel$" },
  blur = true,
  ignore_alpha = 0.05,
})

-- ---------------------------------------------------------------------------
-- Fenêtres flottantes comme sur Mac ([windows] floating) : chaque fenêtre s'ouvre
-- centrée à ~64 × 68 % de l'écran, en léger décalage de la précédente ; le clic
-- donne le focus (la molette agit sous le pointeur, comme macOS). Les apps qui ont
-- déjà leur propre règle flottante (Omarchy) gardent leur taille. ⌘T remet une
-- fenêtre en mosaïque. Nécessaire aux barres de titre, que le greffon ne dessine
-- que sur les fenêtres flottantes.
-- ---------------------------------------------------------------------------
local MAC_FLOATED = "liquid-glass-floated"
local OPEN_W, OPEN_H = "min(1100,monitor_w*0.64)", "min(760,monitor_h*0.68)"

local function not_floating_on_their_own(match)
  local floating = o.floating_apps or { class = {}, title = {}, tags = {}, tagged = {} }
  local excluded = { class = { "omasnap" }, title = {} }
  for _, key in ipairs({ "class", "title" }) do
    for _, pattern in ipairs(floating[key] or {}) do table.insert(excluded[key], pattern) end
  end
  for tag in pairs(floating.tags or {}) do
    for _, tagged in ipairs((floating.tagged or {})[tag] or {}) do
      if excluded[tagged.key] then table.insert(excluded[tagged.key], tagged.pattern) end
    end
  end
  for _, key in ipairs({ "class", "title" }) do
    if #excluded[key] > 0 then
      local alts = {}
      for _, pattern in ipairs(excluded[key]) do table.insert(alts, "(?:" .. pattern .. ")") end
      match[key] = "negative:" .. table.concat(alts, "|")
    end
  end
  return match
end

if val("mac_windows", true) then
  hl.config({ input = { follow_mouse = 2 } })
  hl.window_rule({ name = "liquid-glass-float", match = { class = ".*" }, float = true })
  hl.window_rule({
    name = "liquid-glass-float-size",
    match = not_floating_on_their_own({ modal = false }),
    size = OPEN_W .. " " .. OPEN_H,
    move = string.format("(monitor_w-%s)/2 (monitor_h-%s)/2+12", OPEN_W, OPEN_H),
    tag = "+" .. MAC_FLOATED,
  })
  -- Fenêtres déjà ouvertes en mosaïque : flottées une seule fois (étiquette), pour
  -- qu'un rechargement ne défasse pas une mise en mosaïque voulue avec ⌘T.
  local step = 0
  for _, w in ipairs(hl.get_windows() or {}) do
    local tagged = false
    for _, t in ipairs(w.tags or {}) do if t == MAC_FLOATED or t == MAC_FLOATED .. "*" then tagged = true end end
    local special = tostring((w.workspace and w.workspace.name) or ""):match("^special") ~= nil
    if not tagged and not w.floating and (w.fullscreen or 0) == 0 and not special then
      local target = "address:" .. w.address
      hl.dispatch(hl.dsp.window.tag({ tag = "+" .. MAC_FLOATED, window = target }))
      hl.dispatch(hl.dsp.window.float({ action = "on", window = target }))
      local m = w.monitor
      if m and m.width then
        local mw, mh = math.floor(m.width / m.scale), math.floor(m.height / m.scale)
        hl.dispatch(hl.dsp.window.resize({ x = math.min(1100, math.floor(mw * 0.64)), y = math.min(760, math.floor(mh * 0.68)), relative = false, window = target }))
        hl.dispatch(hl.dsp.window.center({ window = target }))
        hl.dispatch(hl.dsp.window.move({ x = step * 24 - 24, y = step * 24, relative = true, window = target }))
        step = (step + 1) % 4
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Barres de titre façon macOS sur TOUTES les fenêtres (Chrome, Spotify, terminaux…).
-- Greffon omarchy-hyprland-titlebars (fork de hyprbars livré par Omarchy pour sa
-- version exacte de Hyprland) : barre de verre de 28 pt, feux rouge / jaune / vert
-- de 12 pt à gauche (symboles au survol, gris quand la fenêtre est inactive),
-- titre centré, double-clic = agrandir. [glass] titlebars = false pour les retirer.
-- ---------------------------------------------------------------------------
local TITLEBARS = "/usr/lib/omarchy-hyprland-titlebars/titlebars.so"
local BAR_TAG = "liquid-glass-titlebar"
-- Pas de barre : vignette de capture, image dans l'image, sélecteurs du portail.
local NO_BAR_CLASS = "^(omasnap|xdg-desktop-portal.*|hyprland-share-picker|hyprpolkitagent)$"
local NO_BAR_TITLE = "^(Picture.in.[Pp]icture|Incrustation vidéo)$"

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

local function theme_is_dark()
  local f = io.open((os.getenv("HOME") or "") .. "/.local/state/omarchy/current/theme/colors.toml", "r")
  if not f then return false end
  local text = f:read("*a") or ""
  f:close()
  return text:match('mode%s*=%s*"dark"') ~= nil
end

local function wants_bar(w)
  return not (tostring(w.class or ""):match("^omasnap") or tostring(w.class or ""):match("^xdg%-desktop%-portal")
    or tostring(w.title or ""):match("^Picture.in.Picture"))
end

if val("titlebars", true) and file_exists(TITLEBARS) then
  hl.plugin.load(TITLEBARS)

  -- Chaque fenêtre porte l'étiquette qui fait dessiner la barre : les nouvelles par
  -- la règle, celles déjà ouvertes ici (une règle ne s'applique qu'à l'ouverture).
  hl.window_rule({
    name = "liquid-glass-titlebar",
    match = { class = "negative:" .. NO_BAR_CLASS, title = "negative:" .. NO_BAR_TITLE },
    tag = "+" .. BAR_TAG,
  })
  for _, w in ipairs(hl.get_windows() or {}) do
    if wants_bar(w) then
      hl.dispatch(hl.dsp.window.tag({ tag = "+" .. BAR_TAG, window = "address:" .. w.address }))
    end
  end

  -- Le greffon recharge la configuration une fois chargé : ses options n'existent
  -- qu'à ce second passage.
  if hl.plugin.hyprbars then
    local dark = theme_is_dark()
    local bar = dark and "rgba(2c2c30e6)" or "rgba(f4f4f6eb)"
    local text = dark and "rgba(ffffffd9)" or "rgba(1d1d1fd9)"
    local idle = dark and "rgba(4d4d4dff)" or "rgba(c7c7c7ff)"
    local window = [[window = "address:%WINDOW%"]]
    local zoom = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " .. window .. " })'"

    hl.config({
      plugin = {
        hyprbars = {
          enabled = true,
          workspace_tag = BAR_TAG,
          bar_height = 28,
          bar_color = bar,
          bar_color_inactive = bar,
          bar_blur = true,
          col = { text = text },
          bar_title_enabled = true,
          bar_text_font = "Inter",
          bar_text_size = 13,
          bar_text_weight = "bold",
          bar_text_align = "center",
          bar_buttons_alignment = "left",
          bar_part_of_window = true,
          bar_precedence_over_border = true,
          bar_padding = 9,
          bar_button_padding = 8,
          button_rounding = -1,
          button_border_size = 0,
          icon_on_hover = true,
          inactive_button_color = idle,
          on_double_click = zoom,
        },
      },
    })

    -- Dans l'ordre macOS, de gauche à droite : fermer, réduire (vers le Dock), agrandir.
    for _, b in ipairs({
      { color = "rgb(ff5f57)", icon = "×", action = "hyprctl dispatch 'hl.dsp.window.close({ " .. window .. " })'" },
      { color = "rgb(febc2e)", icon = "−", action = "liquid-glass window minimize %WINDOW%" },
      -- Vert : menu Plein écran / Mosaïque façon Tahoe (Réglages → Bureau et Dock), ou agrandir.
      { color = "rgb(28c840)", icon = "+", action = val("green_menu", true) and "liquid-glass tile-menu %WINDOW%" or zoom },
    }) do
      hl.plugin.hyprbars.add_button({ bg_color = b.color, fg_color = "rgba(00000099)", size = 12, icon = b.icon, action = b.action })
    end
  end
end

-- Souris et trackpad (Réglages → Souris / Trackpad, [input] de config.toml).
if type(v.input) == "table" then hl.config({ input = v.input }) end

-- ---------------------------------------------------------------------------
-- Raccourcis façon macOS (désactivables : [keys] macos_shortcuts = false).
-- ---------------------------------------------------------------------------
-- ⌘⇧Espace : sélecteur de bureaux (Mac et styles Linux), quels que soient les
-- raccourcis macOS. Omarchy y mettait « afficher/masquer la barre ».
o.rebind("SUPER + SHIFT + SPACE", "Bureaux (Mac, Blanc, Sombre, Jouet, Violet…)", "liquid-glass profile pick")

if val("keybindings", true) then
  local ok_keys, err = pcall(require, "liquid-glass-bindings")
  if not ok_keys then hl.exec_cmd(o.notify("Liquid Glass : raccourcis non chargés — " .. tostring(err))) end
end
