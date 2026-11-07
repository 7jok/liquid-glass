-- Thème « automne » (profil Linux) : bordure en dégradé à 45°.
-- Généré par scripts/gen-linux-themes.py ; le service du bureau Linux affine
-- ensuite bordures, arrondis et ombres selon le style.
local active_border_color = { colors = { "rgba(f0915aff)", "rgba(c9708aff)" }, angle = 45 }
local inactive_border_color = "rgba(4a2a26aa)"

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
