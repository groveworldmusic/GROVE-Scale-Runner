-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: Centralized UI Constants
-- Magic numbers removed — all hardcoded values live here.

local constants = {}

-- =========================================================
-- Window dimensions
-- =========================================================
constants.WINDOW_WIDTH = 720
constants.WINDOW_HEIGHT = 497              -- collapsed state
constants.WINDOW_HEIGHT_EXPANDED = 793     -- MIDI island expanded
constants.PANEL_WIDTH = 304                -- compact panel floating width
constants.PANEL_HEIGHT = 171              -- compact panel floating height
constants.PANEL_PIANO_H = 128             -- piano keyboard area inside panel
constants.TRANSPORT_BAR_HEIGHT = 26       -- compact bar height
constants.BAR_GAP = 4                     -- spacing between tool buttons, snap gap

-- =========================================================
-- Zoom constraints (piano roll)
-- =========================================================
constants.ZOOM_MIN = 10    -- pixels per beat
constants.ZOOM_MAX = 200   -- pixels per beat

-- =========================================================
-- Keyboard / Input
-- =========================================================
constants.CTRL_D_KEY = 4                   -- char code for Ctrl+D (dock toggle)
constants.DRAG_THRESHOLD = 8              -- pixels: minimum drag distance before initiating drag
constants.FOCUS_THROTTLE = 0.05           -- seconds between focus checks (keyboard.lua)

-- =========================================================
-- Default values
-- =========================================================
constants.DEFAULT_OCTAVE = 4
constants.DEFAULT_VELOCITY = 100
constants.DEFAULT_DURATION = 4            -- beats

-- =========================================================
-- Piano roll / grid
-- =========================================================
constants.TOTAL_PITCHES = 108             -- C0 (pitch 12) to B8 (pitch 119)
constants.PITCH_ROW_H = 16                -- pixels per pitch row
constants.OCTAVE_BUFFER = 4               -- extra pitch rows for edge stability during scroll

-- =========================================================
-- Logging control (api-guard.lua)
-- =========================================================
constants.CLAMP_LOGGING = false           -- set true to enable ClampIndex console warnings

-- =========================================================
-- Scrollbar / UI geometry
-- =========================================================
constants.SB_WIDTH = 6                    -- scrollbar thumb width
constants.SB_MIN_HEIGHT = 8               -- scrollbar thumb minimum height
constants.SCROLLBAR_COLOR = {0.4, 0.4, 0.4, 0.3}

-- =========================================================
-- Note rendering
-- =========================================================
constants.NOTE_MUTED = {0.4, 0.4, 0.4, 0.4}
constants.NOTE_MUTED_OPAQUE = {0.4, 0.4, 0.4, 1.0}
constants.NOTE_SELECTED_BORDER = {1, 1, 1, 0.8}

-- =========================================================
-- Interaction timing
-- =========================================================
constants.POST_MENU_GUARD_MS = 200        -- ignore clicks for 200ms after context menu dismiss (compact-intercept)

-- =========================================================
-- File I/O
-- =========================================================
constants.MAX_PRESET_NAME_DISPLAY = 16    -- truncate preset name display length

return constants
