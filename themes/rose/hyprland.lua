-- Thème « rose » (profil Linux) : bordure en dégradé à 45°.
-- Généré par scripts/gen-linux-themes.py ; le service du bureau Linux affine
-- ensuite bordures, arrondis et ombres selon le style.
local active_border_color = { colors = { "rgba(8a3e5cff)", "rgba(9b6bd1ff)" }, angle = 45 }
local inactive_border_color = "rgba(f0cfdbff)"

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
