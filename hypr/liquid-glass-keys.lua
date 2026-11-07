-- ============================================================================
-- Liquid Glass — son du clavier (Mechvibes) SANS groupe « input ».
--
-- Hyprland reçoit déjà toutes les frappes : on ne donne l'accès au clavier à
-- aucune application. À chaque touche, on ajoute une ligne à un petit fichier
-- privé ($XDG_RUNTIME_DIR/liquid-glass-keys, mode 600) que lit le lecteur
-- `liquid-glass-keys`. Rien n'y révèle ce qui est tapé :
--   * lettres, chiffres, ponctuation → « k » (le lecteur tire un son de lettre au hasard) ;
--   * seules les touches « bruyantes » gardent leur code (espace, entrée, retour
--     arrière, tab, maj, ctrl, alt, super, échap, flèches, F1–F12…).
-- Le fichier n'existe que quand le lecteur tourne : sinon, rien n'est écrit.
-- ============================================================================

local path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/liquid-glass-keys"

-- Codes evdev des touches dont le son est propre (pas d'information sur le texte).
local LOUD = {}
for _, c in ipairs({ 1, 14, 15, 28, 29, 42, 54, 56, 57, 58, 97, 100, 125, 126, 127,
                     102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
                     59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 87, 88 }) do LOUD[c] = true end

local fh, checked = nil, -1
local function sink()
  local now = os.time()
  if now ~= checked then          -- au plus une fois par seconde
    checked = now
    -- On rouvre à chaque fois : si le lecteur a redémarré, le fichier a été
    -- recréé et l'ancien descripteur pointerait vers un fichier supprimé (plus
    -- aucun son, sans erreur).
    if fh then
      fh:close()
      fh = nil
    end
    local probe = io.open(path, "r")
    if probe then
      probe:close()
      fh = io.open(path, "a")
      if fh then fh:setvbuf("no") end
    end
  end
  return fh
end

-- Clics de souris : même fichier, un simple « m » (ni position, ni fenêtre). Les
-- raccourcis sont non bloquants : le clic arrive toujours à l'application.
local function click(state)
  return function()
    pcall(function()
      local f = sink()
      if f then f:write("m" .. state .. "\n") end
    end)
  end
end
for _, button in ipairs({ "mouse:272", "mouse:273" }) do
  hl.bind(button, click("d"), { non_consuming = true, ignore_mods = true })
  hl.bind(button, click("u"), { non_consuming = true, ignore_mods = true, release = true, transparent = true })
end

hl.on("input.keyboard.key", function(code, _, state)
  if state ~= 0 and state ~= 1 then return end
  pcall(function()
    local f = sink()
    if f then f:write((LOUD[code] and tostring(code) or "k") .. (state == 1 and "d\n" or "u\n")) end
  end)
end)
