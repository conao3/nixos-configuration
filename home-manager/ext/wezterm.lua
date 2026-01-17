local wezterm = require('wezterm')
local act = wezterm.action

return {
    font = wezterm.font 'HackGen Console NF',
    font_size = 12,
    window_padding = { left = 1, right = 0, top = 0, bottom = 0 },
    leader = { key = 'o', mods = 'CTRL', timeout_milliseconds = 1000 },
}
