-- Thème « lain » (profil Linux) : bordure 2 px en dégradé sarcelle → bleu à 45°,
-- inactive grise translucide, comme dans les dotfiles Teiguuu (couleurs pywal).
local active_border_color = { colors = { "rgba(2f9e9eee)", "rgba(3f7fb5ee)" }, angle = 45 }
local inactive_border_color = "rgba(333333aa)"

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
