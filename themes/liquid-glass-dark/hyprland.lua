-- Liquid Glass — bordures des fenêtres. FICHIER GÉNÉRÉ par render-theme.py.
-- Liseré fin, blanc translucide, sans couleur agressive.
local active_border_color = "rgba(ffffff38)"
local inactive_border_color = "rgba(ffffff1a)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },
  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})
