-- Thème « mono sakura » (profil Linux) : bordure en dégradé à 45°.
-- Généré par scripts/gen-linux-themes.py ; le service du bureau Linux affine
-- ensuite bordures, arrondis et ombres selon le style.
local active_border_color = { colors = { "rgba(f7a8c4cc)", "rgba(ffc9a8cc)" }, angle = 45 }
local inactive_border_color = "rgba(4a3240ff)"

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
