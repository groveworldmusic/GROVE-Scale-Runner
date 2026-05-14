-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
local config = require("config")
local layout = require("ui.layout")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local island_store = require("state.island")
local ui_store = require("state.ui")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local midi = require("core.midi")
local piano_roll = require("ui.piano-roll")
local timeline = require("ui.timeline")
local velocity = require("ui.velocity")
local preset_browser = require("ui.preset-browser")

-- Sub-modules (Phase 1 Refactor)
local header = require("ui.midi-island.header")
local input = require("ui.midi-island.input")

local m = {}

-- Preset panel zoom toggle state
local _saved_zoom_x = nil
local _prev_panel_visible = false

-- Track progression revision
local _island_progression_revision = -1

-- Scrollbar drag states
local _sb_dragging = false
local _sb_drag_start_x = 0
local _sb_scroll_at_drag_start = 0

local _vsb_dragging = false
local _vsb_drag_start_y = 0
local _vsb_scroll_at_drag_start = 0

local function DrawPresetPanel(island_x, y, preset_w, h)
    if preset_w > 0 then
        local p_radius = 10
        helpers.SetColor(theme.colors.island_panel_bg)
        components.DrawRoundedRectEx(island_x, y, preset_w, h, p_radius, {tl=true})

        local browser_y = y + 4
        local browser_h = h - 4
        local root = island_store.GetPresetRoot()
        if not root or #root == 0 then preset_browser.Init() end
        preset_browser.DrawPresetBrowser(island_x, browser_y, preset_w, browser_h)
    end
end

function m.Draw(char)
    if not midi.midi_island_expanded then
        _island_progression_revision = -1
        _sb_dragging, _vsb_dragging = false, false
        if island_store.GetLassoActive() then island_store.SetLassoActive(false) end
        return
    end

    -- Reload notes from progression if needed
    local cur_rev = seq_store.GetProgressionRevision()
    if cur_rev ~= _island_progression_revision then
        island_store.LoadNotesFromProgression(seq_store)
        piano_roll.MarkNotesDirty()
        _island_progression_revision = cur_rev
    end

    -- 1. Input Handling
    input.HandleKeyboard(char)

    -- 2. Header
    local content_w = layout.US(39914)
    header.DrawHeader(content_w)

    -- 3. Layout Calculations
    local btn_y_v = 27738 + 428
    local b_h = layout.US(1980)
    local gap_v = math.floor((15455 - 1980 * 5) / 4 + 1422)
    local island_y_v = btn_y_v + b_h + gap_v - 428
    local y = layout.UY(island_y_v)
    local w = layout.US(39914)
    local h = layout.US(14000)
    
    local SB_SIZE = 7
    local LABEL_W = piano_roll.PITCH_LABEL_W
    local island_x = layout.UX(0)
    local preset_w = island_store.GetPresetPanelVisible() and 220 or 0
    local right_x = island_x + preset_w
    local right_w = w - preset_w
    
    local tl_h = timeline.TIMELINE_H
    local vel_expanded = island_store.GetVelocityPanelExpanded()
    local base_ve_h = vel_expanded and velocity.EDITOR_H or velocity.COLLAPSED_H
    local pr_y = y + tl_h
    local pr_h_full = h - tl_h - base_ve_h - SB_SIZE
    local excess = pr_h_full % piano_roll.PITCH_ROW_H
    local pr_h = pr_h_full - excess
    local ve_y = pr_y + pr_h
    local ve_h = base_ve_h + excess
    local sb_y = y + h - SB_SIZE
    local grid_w = right_w - LABEL_W - SB_SIZE

    -- Zoom toggle logic
    local panel_visible = island_store.GetPresetPanelVisible()
    if panel_visible and not _prev_panel_visible then
        _saved_zoom_x = island_store.GetZoomX()
        island_store.SetZoomX(math.max(10, math.min(200, math.floor(right_w / 16 + 0.5))))
    elseif not panel_visible and _prev_panel_visible then
        if _saved_zoom_x then island_store.SetZoomX(_saved_zoom_x); _saved_zoom_x = nil end
    end
    _prev_panel_visible = panel_visible

    -- 4. Rendering
    DrawPresetPanel(island_x, y, preset_w, h)

    if right_w > 0 then
        local content_radius = 10
        local has_presets = island_store.GetPresetPanelVisible()
        
        -- Chasis & Spine
        helpers.SetColor(theme.colors.island_bg)
        components.DrawRoundedRectEx(right_x, y, right_w, h, content_radius, {tl=not has_presets, tr=true, bl=not has_presets, br=true})
        components.DrawIslandSpine(right_x, y, LABEL_W, h, content_radius, {tl=not has_presets, tr=false, bl=not has_presets, br=false})

        -- Sub-modules
        piano_roll.DrawPianoRoll(right_x, pr_y, right_w - SB_SIZE, pr_h)
        if ve_h > 0 then
            velocity.DrawVelocityEditor(right_x, ve_y, right_w - SB_SIZE, ve_h, island_store.GetNotes(), island_store.GetScrollOffsetX(), island_store.GetZoomX(), island_store.GetSelectedNoteIndex())
        end
        timeline.DrawTimelineRuler(right_x, y, right_w + 1, tl_h, pr_h, grid_w, not has_presets)
        
        -- 5. Mouse Dispatch
        local ctx = {
            right_x = right_x, right_w = right_w, SB_SIZE = SB_SIZE,
            y = y, h = h, pr_y = pr_y, pr_h = pr_h, ve_y = ve_y, ve_h = ve_h,
            tl_h = tl_h, grid_w = grid_w, sb_y = sb_y, sb_h = SB_SIZE
        }
        input.HandleMouse(ctx)

        -- 6. Scrollbars (UI Layer)
        m.DrawScrollbars(right_x, LABEL_W, grid_w, pr_y, pr_h, ve_h, sb_y, SB_SIZE)
    end
end

function m.DrawScrollbars(right_x, LABEL_W, grid_w, pr_y, pr_h, ve_h, sb_y, SB_SIZE)
    local scroll_x = island_store.GetScrollOffsetX()
    local zoom_x = island_store.GetZoomX()
    local total_beats = 64
    local notes = island_store.GetNotes()
    for _, n in ipairs(notes) do total_beats = math.max(total_beats, (n.start_beat or 0) + (n.duration or 4) + 4) end

    -- Horizontal
    local visible_beats = math.ceil(grid_w / math.max(1, zoom_x))
    if visible_beats < total_beats then
        local max_scroll_x = total_beats - visible_beats
        local bar_w = math.max(20, grid_w * (visible_beats / total_beats))
        local track_w = grid_w - bar_w
        local bar_x = right_x + LABEL_W + (math.min(scroll_x, max_scroll_x) / max_scroll_x) * track_w
        
        helpers.SetColor({0.15, 0.15, 0.15, 0.25})
        components.DrawRoundedRectEx(right_x + LABEL_W, sb_y, grid_w, SB_SIZE, 4, {bl=false, br=true})
        
        local mx, my = gfx.mouse_x, gfx.mouse_y
        if ui_store.GetMouseClick() and mx >= bar_x and mx <= bar_x + bar_w and my >= sb_y and my <= sb_y + SB_SIZE then
            _sb_dragging, _sb_drag_start_x, _sb_scroll_at_drag_start = true, mx, math.min(scroll_x, max_scroll_x)
        end
        if _sb_dragging then
            if (gfx.mouse_cap & 1) == 0 then _sb_dragging = false
            else island_store.SetScrollOffsetX(math.max(0, math.min(max_scroll_x, _sb_scroll_at_drag_start + ((mx - _sb_drag_start_x) / grid_w) * total_beats))) end
        end
        helpers.SetColor(theme.colors.island_scrollbar_bg or {0.4, 0.4, 0.4, 0.35})
        components.DrawRoundedRect(bar_x, sb_y, bar_w, SB_SIZE, 2, true)
    end

    -- Vertical
    local scroll_y = island_store.GetScrollOffsetY()
    local TOTAL_PITCHES = 108
    local vsb_x, vsb_w = right_x + grid_w + LABEL_W, SB_SIZE
    local vsb_h = pr_h + (ve_h > 0 and ve_h or 0) - 7
    local visible_rows = pr_h / math.max(1, piano_roll.PITCH_ROW_H)
    if visible_rows < TOTAL_PITCHES then
        local max_scroll_y = TOTAL_PITCHES - visible_rows
        helpers.SetColor({0.15, 0.15, 0.15, 0.25})
        components.DrawRoundedRect(vsb_x, pr_y, vsb_w, vsb_h, 2, true)

        local bar_h = math.max(14, vsb_h * (visible_rows / TOTAL_PITCHES))
        local track_h = vsb_h - bar_h
        local bar_y = pr_y + (math.min(scroll_y, max_scroll_y) / max_scroll_y) * track_h
        
        local mx, my = gfx.mouse_x, gfx.mouse_y
        if ui_store.GetMouseClick() and mx >= vsb_x and mx <= vsb_x + vsb_w and my >= bar_y and my <= bar_y + bar_h then
            _vsb_dragging, _vsb_drag_start_y, _vsb_scroll_at_drag_start = true, my, math.min(scroll_y, max_scroll_y)
        end
        if _vsb_dragging then
            if (gfx.mouse_cap & 1) == 0 then _vsb_dragging = false
            else island_store.SetScrollOffsetY(math.max(0, math.min(max_scroll_y, _vsb_scroll_at_drag_start + ((my - _vsb_drag_start_y) / vsb_h) * max_scroll_y))) end
        end
        helpers.SetColor(theme.colors.island_scrollbar_bg or {0.4, 0.4, 0.4, 0.35})
        components.DrawRoundedRect(vsb_x, bar_y, vsb_w, bar_h, 2, true)
    end
end

return m
