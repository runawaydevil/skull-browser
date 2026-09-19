-------------------------------
-- Skull Browser theme       --
-------------------------------
--
-- Names cascade: tab_selected_fg falls back to selected_fg, then to fg. Change
-- the handful of keys under "Palette" and the rest of the interface follows.

local theme = {}

-- Palette
local bg        = "#0b0d11"  -- window and status bar
local bg_raised = "#11151b"  -- tab strip
local bg_sunken = "#070910"  -- inactive surfaces
local line      = "#1e242e"

local fg        = "#e9e5d9"  -- bone
local fg_dim    = "#98a0ae"
local fg_faint  = "#5d6470"

local phos      = "#3df07a"  -- phosphor green, the accent
local cyan      = "#35d6c3"
local amber     = "#e8b23a"
local blood     = "#e05260"

-- Default settings
theme.font = "11px monospace"
theme.fg   = fg
theme.bg   = bg

-- General colours
theme.success_fg = phos
theme.loaded_fg  = cyan
theme.error_fg   = bg
theme.error_bg   = blood

-- Warning colours
theme.warning_fg = bg
theme.warning_bg = amber

-- Notification colours
theme.notif_fg = phos
theme.notif_bg = bg_raised

-- Menu colours
theme.menu_fg                   = fg
theme.menu_bg                   = bg_raised
theme.menu_selected_fg          = bg
theme.menu_selected_bg          = phos
theme.menu_title_bg             = bg_sunken
theme.menu_primary_title_fg     = phos
theme.menu_secondary_title_fg   = fg_faint

theme.menu_disabled_fg = fg_faint
theme.menu_disabled_bg = theme.menu_bg
theme.menu_enabled_fg  = theme.menu_fg
theme.menu_enabled_bg  = theme.menu_bg
theme.menu_active_fg   = cyan
theme.menu_active_bg   = theme.menu_bg

-- Proxy manager
theme.proxy_active_menu_fg      = phos
theme.proxy_active_menu_bg      = bg_raised
theme.proxy_inactive_menu_fg    = fg_faint
theme.proxy_inactive_menu_bg    = bg_raised

-- Statusbar specific
theme.sbar_fg         = fg_dim
theme.sbar_bg         = bg

-- Downloadbar specific
theme.dbar_fg         = fg_dim
theme.dbar_bg         = bg
theme.dbar_error_fg   = blood

-- Input bar specific
theme.ibar_fg           = fg
theme.ibar_bg           = "rgba(0,0,0,0)"

-- Tab label
theme.tab_fg            = fg_faint
theme.tab_bg            = bg_raised
theme.tab_hover_bg      = line
theme.tab_ntheme        = fg_dim
theme.selected_fg       = fg
theme.selected_bg       = bg
theme.selected_ntheme   = phos
theme.loading_fg        = cyan
theme.loading_bg        = bg

-- Private tabs read as a different mode, not a different shade of the same one
theme.selected_private_tab_bg = "#2a2340"
theme.private_tab_bg          = "#1c1830"

-- Trusted, excused and untrusted connections
theme.trust_fg          = phos
theme.notrust_fg        = blood

-- Follow mode hints
theme.hint_font                    = "10px monospace"
theme.hint_fg                      = bg
theme.hint_bg                      = phos
theme.hint_border                  = "1px solid " .. bg
theme.hint_opacity                 = "0.92"
theme.hint_overlay_bg              = "rgba(61,240,122,0.16)"
theme.hint_overlay_border          = "1px solid rgba(61,240,122,0.5)"
theme.hint_overlay_selected_bg     = "rgba(53,214,195,0.3)"
theme.hint_overlay_selected_border = "1px solid " .. cyan

-- General colour pairings
theme.ok    = { fg = fg,    bg = bg_raised }
theme.warn  = { fg = bg,    bg = amber }
theme.error = { fg = bg,    bg = blood }

-- Small web page style. gopher:// and gemini:// share it.
theme.gopher_light = { bg = "#f4f2ec", fg = "#15181d", link = "#0d7d71" }
theme.gopher_dark  = { bg = bg,        fg = fg,        link = cyan }

return theme

-- vim: et:sw=4:ts=8:sts=4:tw=80
