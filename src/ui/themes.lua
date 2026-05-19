-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Color Theme Definitions
-- Each entry has `name` (string) and `colors` (table matching theme.lua keys).
-- THEMES[idx] is accessed by preference store theme_index (1..3).
local THEMES = {
    --- Current: existing default palette (copied from theme.lua hex values)
    {
        name = "Current",
        colors = {
            bg = {0.051, 0.051, 0.051, 1},
            text = {0.902, 0.902, 0.902, 1},
            text_dim = {0.522, 0.522, 0.522, 1},
            text_dark = {0.102, 0.102, 0.102, 1},
            btn_bg = {0.200, 0.200, 0.200, 1},
            btn_hover = {0.267, 0.267, 0.267, 1},
            btn_active = {0.247, 0.506, 0.855, 1},
            pad_active = {0.247, 0.506, 0.855, 1},
            island_bg = {0.200, 0.200, 0.200, 1},
            bar_bg = {0.141, 0.141, 0.141, 1},
            slot_filled = {0.247, 0.506, 0.855, 1},
            slot_playing = {0.420, 0.651, 0.349, 1},
            piano_white = {0.851, 0.851, 0.851, 1},
            piano_black = {0.051, 0.051, 0.051, 1},
            page_inactive = {0.102, 0.102, 0.102, 1},
            page_active = {0.502, 0.502, 0.502, 1},
            island_grid_line = {0.227, 0.227, 0.227, 1},
            island_note_default = {0.247, 0.506, 0.855, 1},
            island_note_selected = {0.357, 0.659, 0.769, 1},
            island_note_muted = {0.333, 0.333, 0.333, 1},
            island_beat_tick = {0.290, 0.290, 0.290, 1},
            island_measure_tick = {0.416, 0.416, 0.416, 1},
            island_info_bar = {0.102, 0.102, 0.102, 1},
            island_panel_bg = {0.141, 0.141, 0.141, 1},
            island_ruler_bg = {0.227, 0.227, 0.227, 1},
            island_velocity_bg = {0.165, 0.165, 0.165, 1},
            island_scrollbar_bg = {0.5, 0.5, 0.5, 1.0},
            grid_measure = {0.5, 0.5, 0.5, 0.60},
            grid_beat = {0.4, 0.4, 0.4, 0.35},
            grid_sub_1_8 = {0.25, 0.25, 0.25, 0.15},
            grid_sub_1_16 = {0.20, 0.20, 0.20, 0.08},
            snap_active = {0.298, 0.686, 0.314, 1},
            snap_inactive = {0.333, 0.333, 0.333, 1},
            snap_grid = {0.30, 0.70, 0.30, 0.25},
            lasso_fill = {0.25, 0.50, 1.0, 0.15},
            lasso_border = {0.25, 0.50, 1.0, 0.50},
            grid_scale_row = {1.0, 1.0, 1.0, 0.03},
            grid_black_key_row = {0.0, 0.0, 0.0, 0.15},
            note_ghost = {1.0, 1.0, 1.0, 0.3},
            grade_colors = {
                {0.247, 0.506, 0.855, 1},  -- I:  blue
                {0.290, 0.620, 0.420, 1},  -- II: green
                {0.831, 0.627, 0.290, 1},  -- III: amber
                {0.788, 0.376, 0.376, 1},  -- IV: red
                {0.608, 0.420, 0.749, 1},  -- V: purple
                {0.357, 0.659, 0.769, 1},  -- VI: teal
                {0.831, 0.478, 0.353, 1},  -- VII: orange
            },
        },
    },

    --- Dark: deeper background, brighter text, more saturated accents
    {
        name = "Dark",
        colors = {
            bg = {0.035, 0.035, 0.035, 1},
            text = {0.95, 0.95, 0.95, 1},
            text_dim = {0.65, 0.65, 0.65, 1},
            text_dark = {0.08, 0.08, 0.08, 1},
            btn_bg = {0.15, 0.15, 0.15, 1},
            btn_hover = {0.22, 0.22, 0.22, 1},
            btn_active = {0.30, 0.65, 0.95, 1},
            pad_active = {0.30, 0.65, 0.95, 1},
            island_bg = {0.025, 0.025, 0.025, 1},
            bar_bg = {0.08, 0.08, 0.08, 1},
            slot_filled = {0.20, 0.50, 0.90, 1},
            slot_playing = {0.35, 0.70, 0.30, 1},
            piano_white = {0.15, 0.15, 0.15, 1},
            piano_black = {0.03, 0.03, 0.03, 1},
            page_inactive = {0.08, 0.08, 0.08, 1},
            page_active = {0.55, 0.55, 0.55, 1},
            island_grid_line = {0.15, 0.15, 0.15, 1},
            island_note_default = {0.25, 0.60, 0.95, 1},
            island_note_selected = {0.35, 0.75, 0.85, 1},
            island_note_muted = {0.25, 0.25, 0.25, 1},
            island_beat_tick = {0.20, 0.20, 0.20, 1},
            island_measure_tick = {0.35, 0.35, 0.35, 1},
            island_info_bar = {0.08, 0.08, 0.08, 1},
            island_panel_bg = {0.10, 0.10, 0.10, 1},
            island_ruler_bg = {0.12, 0.12, 0.12, 1},
            island_velocity_bg = {0.15, 0.15, 0.15, 1},
            island_scrollbar_bg = {0.35, 0.35, 0.35, 1.0},
            grid_measure = {0.45, 0.45, 0.45, 0.55},
            grid_beat = {0.35, 0.35, 0.35, 0.30},
            grid_sub_1_8 = {0.18, 0.18, 0.18, 0.12},
            grid_sub_1_16 = {0.12, 0.12, 0.12, 0.06},
            snap_active = {0.4, 0.733, 0.416, 1},
            snap_inactive = {0.25, 0.25, 0.25, 1},
            snap_grid = {0.35, 0.75, 0.35, 0.20},
            lasso_fill = {0.25, 0.60, 1.0, 0.12},
            lasso_border = {0.25, 0.60, 1.0, 0.45},
            grid_scale_row = {1.0, 1.0, 1.0, 0.02},
            grid_black_key_row = {0.0, 0.0, 0.0, 0.10},
            note_ghost = {1.0, 1.0, 1.0, 0.25},
            grade_colors = {
                {0.29, 0.565, 0.851, 1},  -- I:  brighter blue
                {0.333, 0.722, 0.424, 1},  -- II: brighter green
                {0.878, 0.690, 0.314, 1},  -- III: brighter amber
                {0.831, 0.376, 0.376, 1},  -- IV: red (unchanged)
                {0.667, 0.467, 0.800, 1},  -- V: brighter purple
                {0.376, 0.753, 0.847, 1},  -- VI: brighter teal
                {0.878, 0.522, 0.333, 1},  -- VII: brighter orange
            },
        },
    },

    --- HighContrast: pure black/white for maximum readability
    {
        name = "HighContrast",
        colors = {
            bg = {0, 0, 0, 1},
            text = {1, 1, 1, 1},
            text_dim = {0.8, 0.8, 0.8, 1},
            text_dark = {0, 0, 0, 1},
            btn_bg = {0.15, 0.15, 0.15, 1},
            btn_hover = {0.25, 0.25, 0.25, 1},
            btn_active = {0.0, 0.75, 1.0, 1},
            pad_active = {0.0, 0.75, 1.0, 1},
            island_bg = {0.05, 0.05, 0.05, 1},
            bar_bg = {0.1, 0.1, 0.1, 1},
            slot_filled = {0.0, 0.5, 1.0, 1},
            slot_playing = {0.0, 0.8, 0.3, 1},
            piano_white = {1, 1, 1, 1},
            piano_black = {0, 0, 0, 1},
            page_inactive = {0.1, 0.1, 0.1, 1},
            page_active = {0.7, 0.7, 0.7, 1},
            island_grid_line = {0.3, 0.3, 0.3, 1},
            island_note_default = {0.3, 0.7, 1.0, 1},
            island_note_selected = {0.5, 0.9, 1.0, 1},
            island_note_muted = {0.4, 0.4, 0.4, 1},
            island_beat_tick = {0.5, 0.5, 0.5, 1},
            island_measure_tick = {0.7, 0.7, 0.7, 1},
            island_info_bar = {0.08, 0.08, 0.08, 1},
            island_panel_bg = {0.08, 0.08, 0.08, 1},
            island_ruler_bg = {0.1, 0.1, 0.1, 1},
            island_velocity_bg = {0.12, 0.12, 0.12, 1},
            island_scrollbar_bg = {0.5, 0.5, 0.5, 1.0},
            grid_measure = {0.6, 0.6, 0.6, 0.8},
            grid_beat = {0.45, 0.45, 0.45, 0.6},
            grid_sub_1_8 = {0.3, 0.3, 0.3, 0.35},
            grid_sub_1_16 = {0.2, 0.2, 0.2, 0.2},
            snap_active = {0.0, 0.902, 0.463, 1},
            snap_inactive = {0.4, 0.4, 0.4, 1},
            snap_grid = {0.0, 0.9, 0.5, 0.3},
            lasso_fill = {0.0, 0.5, 1.0, 0.2},
            lasso_border = {0.0, 0.7, 1.0, 0.7},
            grid_scale_row = {1.0, 1.0, 1.0, 0.05},
            grid_black_key_row = {0.0, 0.0, 0.0, 0.2},
            note_ghost = {1.0, 1.0, 1.0, 0.4},
            grade_colors = {
                {0, 0.4, 1, 1},        -- I:  pure blue
                {0, 0.8, 0.267, 1},    -- II: pure green
                {1, 0.8, 0, 1},        -- III: pure yellow
                {1, 0.2, 0, 1},        -- IV: pure red
                {0.6, 0, 1, 1},        -- V:  pure purple
                {0, 0.8, 0.8, 1},      -- VI: pure cyan
                {1, 0.4, 0, 1},        -- VII: pure orange
            },
        },
    },
}

return THEMES
