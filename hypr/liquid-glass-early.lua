-- ============================================================================
-- Liquid Glass — chargé AVANT les défauts d'Omarchy (début de hyprland.lua).
--
-- Le mode « bureau flottant » d'Omarchy (Super+L, Apparence → Disposition des
-- bureaux) ajoute au même greffon de barres de titre ses propres boutons × □ −
-- et ses réglages. Avec les feux tricolores de Liquid Glass, ça faisait six
-- boutons par fenêtre. Sur le profil Mac (barres de titre activées), seuls les
-- appels de hypr/liquid-glass.lua passent : il pose LG_TITLEBARS = true le temps
-- de configurer le greffon. Profils Linux / Omarchy ou [glass] titlebars = false :
-- rien n'est filtré, Omarchy garde ses barres.
-- ============================================================================
pcall(function()
  local ok, v = pcall(dofile, (os.getenv("HOME") or "") .. "/.config/liquid-glass/hypr-vars.lua")
  if not ok or type(v) ~= "table" then v = {} end
  if (v.profile or "mac") ~= "mac" or v.titlebars == false then return end
  if type(hl) ~= "table" or type(hl.plugin) ~= "table" or hl.plugin.__lg_guard then return end
  hl.plugin.__lg_guard = true

  -- Boutons : ceux d'Omarchy sont ignorés.
  local function guard()
    local hb = hl.plugin.hyprbars
    if type(hb) ~= "table" or hb.__lg_guard or type(hb.add_button) ~= "function" then return end
    local add = hb.add_button
    hb.add_button = function(...)
      if LG_TITLEBARS then return add(...) end
    end
    hb.__lg_guard = true
  end

  -- Le greffon n'existe qu'une fois chargé : on le garde à chaque chargement.
  local load = hl.plugin.load
  if type(load) == "function" then
    local function after(...) guard() return ... end
    hl.plugin.load = function(...) return after(load(...)) end
  end

  -- Réglages du greffon (couleur, boutons à droite, police…) : seuls les nôtres.
  local config = hl.config
  if type(config) == "function" then
    hl.config = function(t, ...)
      if not LG_TITLEBARS and type(t) == "table" and type(t.plugin) == "table" and t.plugin.hyprbars ~= nil then
        local copy = {}
        for k, x in pairs(t) do copy[k] = x end
        local plugin = {}
        for k, x in pairs(t.plugin) do if k ~= "hyprbars" then plugin[k] = x end end
        copy.plugin = next(plugin) and plugin or nil
        if next(copy) == nil then return end
        t = copy
      end
      return config(t, ...)
    end
  end

  guard()
end)
