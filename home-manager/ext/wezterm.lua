local wezterm = require('wezterm')
local config = wezterm.config_builder()
local act = wezterm.action

config.font = wezterm.font 'HackGen Console NF'
config.font_size = 12
config.window_padding = { left = 1, right = 0, top = 0, bottom = 0 }
config.window_decorations = "RESIZE"
config.use_fancy_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.colors = {
    tab_bar = {
        background = "none"
    }
}

return config
