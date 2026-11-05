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
  match = { namespace = "^(omarchy-dock|omarchy-launcher|omarchy-lock.*|liquid-glass-(spotlight|mission|switcher|karaoke|lyrics-widget|cheatsheet|settings))$" },
  blur = true,
  ignore_alpha = 0.05,
})

-- ---------------------------------------------------------------------------
-- Raccourcis façon macOS (désactivables : [keys] macos_shortcuts = false).
-- ---------------------------------------------------------------------------
if val("keybindings", true) then
  local ok_keys, err = pcall(require, "liquid-glass-bindings")
  if not ok_keys then hl.exec_cmd(o.notify("Liquid Glass : raccourcis non chargés — " .. tostring(err))) end
end
