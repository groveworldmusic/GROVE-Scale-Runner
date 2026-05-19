-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
local config = require("config")
local layout = require("ui.layout")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local components = require("ui.components")
local island_store = require("state.island")
local note_store = require("state.note-store")
local preset_store = require("state.preset-store")
local ui_store = require("state.ui")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local prefs = require("state.preferences")
local midi = require("core.midi")
local piano_roll = require("ui.piano-roll")
local remap = require("ui.midi-island.remap")
local timeline = require("ui.timeline")
local velocity = require("ui.velocity")
local preset_browser = require("ui.preset-browser")

-- Sub-modules (Phase 1 Refactor)
local header = require("ui.midi-island.header")
local input = require("ui.midi-island.input")

-- Initialize preset browser once at module load time (hoisted out of DrawPresetPanel)
local function InitPresetBrowser()
    local root = preset_store.GetPresetRoot()
    if not root or #root == 0 then preset_browser.Init() end
end
InitPresetBrowser()

local m = {}

-- Preset panel zoom toggle state
local _saved_zoom_x = nil
local _prev_panel_visible = false
-- Deferred zoom toggle: SetZoomX is applied at the start of the next Draw()
-- call instead of mid-frame during rendering (PR: midi-island-critical-fixes).
local _pending_zoom_target = nil

-- Track progression revision
local _island_progression_revision = -1

-- total_beats cache for scrollbar (avoids O(N) per-frame scan)
local _cached_total_beats = 64
local _cached_total_beats_valid = false
local _cached_notes_count = 0

-- Tracks last progression revision that was auto-focused.
-- When revision changes (progression slot added/edited) and toggle is ON,
-- AutoFocusNotes runs to center the piano roll on all notes.
local _last_focused_revision = -1

-- Cached gfx.h for window resize detection (Phase: batch-c-piano-visual).
-- When height changes by more than 20px, re-trigger AutoFocusNotes.
local _last_gfx_h = nil

-- Cached minimum island content height in pixels, captured on first draw.
-- This prevents the minimum from shifting when gfx.w changes the scale factor.
-- ToggleIsland() always recreates the window at 720×793, so first draw
-- captures the correct default height regardless of prior resize.
local _min_island_px = nil

-- Layout constants (virtual coordinate system, canvas 39914×29162)
local CANVAS_W = layout.CANVAS_W                       -- Canvas width in virtual units
local ISLAND_CONTENT_H = 14000                              -- Min island height in virtual units (clamped)
local BTN_TOP_V = 27738                                 -- Button area top Y in virtual coords
local BTN_Y_OFFSET = 428                                -- Offset from button area top to buttons
local BTN_H = 1980                                      -- Single button height in virtual coords
local BTN_AREA_H = 15455                                -- Total button area height (5 x BTN_H + 4 gaps)
local BTN_GAP_EXTRA = 1422                              -- Extra gap spacing adjust

-- (T3 resolved: preset_browser.Init() is called once at module load)

local THUMB_SIZE = 5  -- Thumb size: 5px in 7px track → 1px margin each side, exact center

-- Scrollbar drag states (Phase 5: moved to island_store — kept as local refs for perf, synced on demand)
-- NOTE: Use island_store.GetSbDragging/SetSbDragging for persistence across island toggle.

local function DrawPresetPanel(island_x, y, preset_w, h)
    if preset_w > 0 then
        local p_radius = 10
        helpers.SetColor(theme.colors.island_panel_bg)
        components.DrawRoundedRectEx(island_x, y, preset_w, h, p_radius, {tl=true, bl=true})

        local browser_y = y + 4
        local browser_h = h - 14
        preset_browser.DrawPresetBrowser(island_x, browser_y, preset_w, browser_h)
    end
end

--- Auto-focus the piano roll viewport to show all notes after loading from progression.
--- Computes the note bounding box, then adjusts zoom_x, scroll_x, and scroll_y so that
--- all notes are comfortably visible (like an inspector).
--- @param grid_w number Available grid width in pixels
--- @param pr_h number Available piano roll height in pixels
local function AutoFocusNotes(grid_w, pr_h)
    local notes = island_store.GetNotes()
    if not notes or #notes == 0 then return end

    local min_pitch, max_pitch = 127, 0
    local min_beat, max_beat = math.huge, -math.huge

    for _, n in ipairs(notes) do
        local p = n.pitch or 60
        if p < min_pitch then min_pitch = p end
        if p > max_pitch then max_pitch = p end
        local sb = n.start_beat or 0
        local nd = n.duration or 1
        if sb < min_beat then min_beat = sb end
        if sb + nd > max_beat then max_beat = sb + nd end
    end

    if max_pitch < min_pitch then return end
    if max_beat <= min_beat then max_beat = min_beat + 1 end

    local PITCH_ROW_H = piano_roll.PITCH_ROW_H
    local MAX_PITCH = piano_roll.MAX_PITCH
    local MIN_PITCH = piano_roll.MIN_PITCH
    local pitch_count = max_pitch - min_pitch + 1

    -- Calculamos PITCH_ROW_H para que entren todas las notas + 1 fila de margen
    -- arriba y 1 abajo (target = count + 2). Ajustamos paridad para que extra sea
    -- par y los márgenes queden exactamente iguales.
    -- visible_pitches = floor(pr_h / PITCH_ROW_H) para trabajar con filas completas.
    local DEFAULT_ROW_H = 16
    local target_rows = pitch_count + 2
    local optimal_h = math.floor(pr_h / target_rows)
    optimal_h = math.max(6, math.min(DEFAULT_ROW_H, optimal_h))

    -- Buscar PITCH_ROW_H que dé extra par (márgenes iguales)
    local candidates = {optimal_h}
    if optimal_h > 6 then table.insert(candidates, optimal_h - 1) end
    if optimal_h < DEFAULT_ROW_H then table.insert(candidates, optimal_h + 1) end
    for _, h in ipairs(candidates) do
        local full_rows = math.floor(pr_h / h)
        if full_rows - pitch_count > 0 and (full_rows - pitch_count) % 2 == 0 then
            optimal_h = h
            break
        end
    end

    -- Aplicar y recalcular con filas exactas
    if optimal_h ~= PITCH_ROW_H then
        piano_roll.SetPitchRowH(optimal_h)
        PITCH_ROW_H = optimal_h
    end
    local full_rows = math.floor(pr_h / PITCH_ROW_H)

    -- Centramos usando SOLO filas completas. Así visible_pitches es entero y
    -- los cálculos de extra/márgenes son exactos.
    local visible_pitches = full_rows
    local center_pitch = (min_pitch + max_pitch) / 2
    local top_pitch = math.min(MAX_PITCH, center_pitch + visible_pitches / 2)
    local target_scroll_y = math.floor(MAX_PITCH - top_pitch + 0.5)
    local max_scroll = piano_roll.TOTAL_ROWS - visible_pitches
    target_scroll_y = math.max(0, math.min(max_scroll, target_scroll_y))
    island_store.SetScrollOffsetY(target_scroll_y)

    -- Horizontal: zoom para que las notas ocupen todo el ancho del grid,
    -- desde el primer beat (borde izquierdo) hasta el último (borde derecho).
    -- Si el zoom excede 200, se clampa (notas más angostas de lo ideal).
    -- Si es menor a 10, se clampa (notas entran sobradas, sobran bordes).
    local beat_span = max_beat - min_beat
    local target_zoom_x = grid_w / beat_span
    target_zoom_x = math.max(10, math.min(200, target_zoom_x))
    island_store.SetZoomX(target_zoom_x)

    -- Scroll para que la primera nota arranque en el borde izquierdo del grid.
    -- Con zoom = grid_w/beat_span, la última nota termina exactamente en el borde derecho.
    island_store.SetScrollOffsetX(min_beat)

    -- Invalidate visible ranges cache so grid/notes re-render at new zoom/scroll
    piano_roll.InvalidateVisibleRangesCache()
end

function m.Draw(char)
    if not island_store.GetMidiIslandExpanded() then
        _island_progression_revision = -1
        _last_focused_revision = -1
        island_store.ResetScrollbarDragState()
        if island_store.GetLassoActive() then island_store.SetLassoActive(false) end
        island_store.SetNotesState(island_store.NOTES_STATE_LOADED)
        return
    end

    -- Apply deferred zoom toggle (set on previous frame, applied before rendering)
    if _pending_zoom_target then
        island_store.SetZoomX(_pending_zoom_target)
        _pending_zoom_target = nil
    end

    -- Reload notes from progression when progression changes (inspector mode).
    -- Always reloads regardless of notes_state so the MIDI island reflects the latest
    -- progression — the user explicitly changed slots, so they want to see those notes.
    local cur_rev = seq_store.GetProgressionRevision()
    if cur_rev ~= _island_progression_revision then
        -- Auto-save current notes to slot-specific file before loading new progression
        local cur_page = seq_store.GetCurrentPage()
        local rev_slot = _island_progression_revision > 0 and _island_progression_revision or nil
        if cur_page and rev_slot then
            local cur_notes = note_store.GetNotes()
            if cur_notes and #cur_notes > 0 then
                preset_browser.SaveSlotSnapshot(cur_page, rev_slot, cur_notes)
            end
        end
        island_store.LoadNotesFromProgression(seq_store, prefs.GetInversionIndex(), prefs.GetInversionDirection())
        _island_progression_revision = cur_rev
        _cached_total_beats_valid = false
    end

    -- Sync playback position from sequencer during playback (only when autoscroll enabled)
    -- Converts (measure + fractional progress) to absolute beats for the playhead cursor.
    -- GetLastMeasure() is -1 when stopped, so the cursor stays hidden before playback starts.
    if seq_store.GetIsPlaying() and island_store.GetAutoscrollEnabled() then
        local cur_m = seq_store.GetLastMeasure()
        if cur_m >= 0 then
            island_store.SetPlaybackPos((cur_m + seq_store.GetProgress()) * 4)
        end
    end

    -- 1. Input Handling (progression focus: mouse NOT in piano roll grid body)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local pre_tl_h = timeline.TIMELINE_H
    local pre_vel_exp = island_store.GetVelocityPanelExpanded()
    local pre_ve_h = pre_vel_exp and velocity.EDITOR_H or velocity.COLLAPSED_H
    local pre_btn_y_v = BTN_TOP_V + BTN_Y_OFFSET
    local pre_b_h = layout.US(BTN_H)
    local pre_gap_v = math.floor((BTN_AREA_H - BTN_H * 5) / 4 + BTN_GAP_EXTRA)
    local pre_island_y_v = pre_btn_y_v + pre_b_h + pre_gap_v - BTN_Y_OFFSET
    local pre_y = layout.UY(pre_island_y_v)
    local pre_w = layout.US(CANVAS_W)
    local pre_h = math.max((_min_island_px or layout.US(ISLAND_CONTENT_H)), gfx.h - pre_y - 10)
    local pre_preset_w = island_store.GetPresetPanelVisible() and 220 or 0
    local pre_right_x = layout.UX(0) + pre_preset_w
    local pre_right_w = pre_w - pre_preset_w
    local pre_pr_y = pre_y + pre_tl_h
    local pre_pr_h = pre_h - pre_tl_h - pre_ve_h - 7  -- SB_SIZE = 7
    local pre_grid_body_x = pre_right_x + piano_roll.PITCH_LABEL_W
    local prog_focused = not (mx >= pre_grid_body_x
                          and mx < pre_grid_body_x + (pre_right_w - piano_roll.PITCH_LABEL_W - 7)
                          and my >= pre_pr_y and my < pre_pr_y + pre_pr_h)
    input.HandleKeyboard(char, prog_focused)

    -- 2. Header (also handles RELOAD + SYNC buttons returning request flags)
    local content_w = layout.US(CANVAS_W)
    local _, reload_requested, sync_requested = header.DrawHeader(content_w)
    if reload_requested then
        island_store.LoadNotesFromProgression(seq_store, prefs.GetInversionIndex(), prefs.GetInversionDirection())
        island_store.SetNotesState(island_store.NOTES_STATE_LOADED)
        _island_progression_revision = seq_store.GetProgressionRevision()
        island_store.ClearSelection()
        _cached_total_beats_valid = false
    end
    if sync_requested then
        note_store.SyncNotesToProgression(seq_store, prefs)
        island_store.SetNotesState(island_store.NOTES_STATE_SYNCED)
        _island_progression_revision = seq_store.GetProgressionRevision()
        _cached_total_beats_valid = false
    end

    -- 3. Layout Calculations
    local btn_y_v = BTN_TOP_V + BTN_Y_OFFSET
    local b_h = layout.US(BTN_H)
    local gap_v = math.floor((BTN_AREA_H - BTN_H * 5) / 4 + BTN_GAP_EXTRA)
    local island_y_v = btn_y_v + b_h + gap_v - BTN_Y_OFFSET
    local y = layout.UY(island_y_v)
    local w = layout.US(CANVAS_W)
    if _min_island_px == nil then                           -- Capture minimum on first draw
        _min_island_px = layout.US(ISLAND_CONTENT_H)
    end
    local h = math.max(_min_island_px, gfx.h - y - 10)      -- 10px bottom margin
    
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
    -- Give any leftover pixels from the pitch row alignment to pr_h
    -- so ve_h stays at its fixed base height (PR: midi-island-header-icons)
    local pr_h = pr_h_full
    local ve_y = pr_y + pr_h
    local ve_h = base_ve_h
    local sb_y = y + h - SB_SIZE
    local grid_w = right_w - LABEL_W - SB_SIZE

    -- Auto-focus piano roll on progression revision change (inspector mode).
    -- Compares last focused revision with current. When they differ (user added/edited
    -- a progression slot), centers the viewport on all notes. Only runs when toggle is ON.
    if prefs.GetAutoFocusEnabled() and _island_progression_revision ~= _last_focused_revision then
        _last_focused_revision = _island_progression_revision
        AutoFocusNotes(grid_w, pr_h)
    end

    -- Auto-focus on window resize: when gfx.h changes by more than 20px,
    -- re-trigger AutoFocusNotes to center notes in the new viewport size.
    if _last_gfx_h ~= nil and math.abs(gfx.h - _last_gfx_h) > 20 and prefs.GetAutoFocusEnabled() then
        piano_roll.InvalidateVisibleRangesCache()
        AutoFocusNotes(grid_w, pr_h)
    end
    _last_gfx_h = gfx.h

    -- Zoom toggle logic (deferred: stores target, applied at start of next Draw call)
    local panel_visible = island_store.GetPresetPanelVisible()
    if panel_visible and not _prev_panel_visible then
        _saved_zoom_x = island_store.GetZoomX()
        _pending_zoom_target = math.max(10, math.min(200, math.floor(right_w / 16 + 0.5)))
    elseif not panel_visible and _prev_panel_visible then
        _pending_zoom_target = _saved_zoom_x or 28
        _saved_zoom_x = nil
    end
    _prev_panel_visible = panel_visible

    -- 4. Rendering
    DrawPresetPanel(island_x, y, preset_w, h)

    if right_w > 0 then
        local content_radius = 10
        local has_presets = island_store.GetPresetPanelVisible()
        
        -- Chasis
        helpers.SetColor(theme.colors.island_bg)
        components.DrawRoundedRectEx(right_x, y, right_w, h, content_radius, {tl=not has_presets, tr=true, bl=not has_presets, br=true})

        -- Spine area: seamless with panel when visible, semi-transparent otherwise
        if has_presets then
            helpers.SetColor(theme.colors.island_panel_bg)
            gfx.rect(right_x, y, LABEL_W, h)
            helpers.SetColor({0.15, 0.15, 0.15, 0.6})
            gfx.line(right_x + LABEL_W, y, right_x + LABEL_W, y + h)
        else
            components.DrawIslandSpine(right_x, y, LABEL_W, h, content_radius, {tl=not has_presets, tr=false, bl=not has_presets, br=false})
        end

        -- Sub-modules
        piano_roll.DrawPianoRoll(right_x, pr_y, right_w - SB_SIZE, pr_h)
        if ve_h > 0 then
            velocity.DrawVelocityEditor(right_x, ve_y, right_w - SB_SIZE, ve_h, island_store.GetNotes(), island_store.GetScrollOffsetX(), island_store.GetZoomX(), island_store.GetSelectedNoteIndex())
        end
        timeline.DrawTimelineRuler(right_x, y, right_w, tl_h, pr_h, not has_presets)
        
        -- 5. Mouse Dispatch
        local ctx = {
            right_x = right_x, right_w = right_w, SB_SIZE = SB_SIZE,
            y = y, h = h, pr_y = pr_y, pr_h = pr_h, ve_y = ve_y, ve_h = ve_h,
            tl_h = tl_h, grid_w = grid_w, sb_y = sb_y, sb_h = SB_SIZE
        }
        input.HandleMouse(ctx)

        -- 6. Scrollbars (UI Layer)
        m.DrawScrollbars(right_x, LABEL_W, grid_w, pr_y, pr_h, ve_h, sb_y, SB_SIZE)

        -- 7. Post-fix: restore spine area from velocity level to bottom edge
        local cr = content_radius
        local bot = y + h
        local spine_h = bot - ve_y
        if has_presets then
            -- Expanded: flat panel_bg + separator
            helpers.SetColor(theme.colors.island_panel_bg)
            gfx.rect(right_x, ve_y, LABEL_W, spine_h)
            helpers.SetColor({0.15, 0.15, 0.15, 0.6})
            gfx.line(right_x + LABEL_W, ve_y, right_x + LABEL_W, bot)
            helpers.SetColor({0.25, 0.25, 0.25, 0.5})
            gfx.rect(right_x, y, 1, h)
        else
            -- Collapsed: island_bg with proper bl rounded corner
            helpers.SetColor(theme.colors.island_bg)
            components.DrawRoundedRectEx(right_x, ve_y, LABEL_W, spine_h, cr, {tl=false, tr=false, bl=true, br=false})
            helpers.SetColor({0.15, 0.15, 0.15, 0.6})
            gfx.line(right_x + LABEL_W, ve_y, right_x + LABEL_W, bot)
        end
    end

    -- 8. Remap modal overlay (drawn on top of everything)
    -- Returns whether Escape was consumed (modal closed instead of script quit)
    local remap_consumed_esc = false
    if remap.GetVisible() then
        remap_consumed_esc = remap.Draw(right_x, y, right_w, h, char)
    end

    return remap_consumed_esc
end

function m.DrawScrollbars(right_x, LABEL_W, grid_w, pr_y, pr_h, ve_h, sb_y, SB_SIZE)
    -- Safety: reset stale scrollbar drag state if mouse button is no longer held
    if island_store.GetSbDragging() and (gfx.mouse_cap & 1) == 0 then island_store.SetSbDragging(false) end
    if island_store.GetVsbDragging() and (gfx.mouse_cap & 1) == 0 then island_store.SetVsbDragging(false) end

    local thumb_offset = math.floor((SB_SIZE - THUMB_SIZE) / 2)
    local scroll_x = island_store.GetScrollOffsetX()
    local zoom_x = island_store.GetZoomX()
    -- Cache-aware total_beats: recompute only when notes array length changes
    local notes = island_store.GetNotes()
    if not _cached_total_beats_valid or _cached_notes_count ~= #notes then
        _cached_total_beats = 64
        for _, n in ipairs(notes) do _cached_total_beats = math.max(_cached_total_beats, (n.start_beat or 0) + (n.duration or 4) + 4) end
        _cached_notes_count = #notes
        _cached_total_beats_valid = true
    end
    local total_beats = _cached_total_beats

    local mx, my = gfx.mouse_x, gfx.mouse_y

    -- Horizontal
    local visible_beats = math.ceil(grid_w / math.max(1, zoom_x))
    if visible_beats < total_beats then
        local max_scroll_x = total_beats - visible_beats
        local bar_w = math.max(20, grid_w * (visible_beats / total_beats))
        local track_w = grid_w - bar_w
        local bar_x = right_x + LABEL_W + (math.min(scroll_x, max_scroll_x) / max_scroll_x) * track_w
        
        -- Track (ends at vsb_x = right edge of grid area)
        helpers.SetColor(theme.colors.island_bg)
        gfx.rect(right_x + LABEL_W, sb_y, grid_w, SB_SIZE)
        
        -- Thumb with hover/active states (opaque → fast path, avoids blit artifacts)
        local is_hover = mx >= bar_x and mx <= bar_x + bar_w and my >= sb_y and my <= sb_y + SB_SIZE
        if island_store.GetSbDragging() then
            helpers.SetColor({0.25, 0.50, 0.85, 1.0}) -- Blue active when dragging
        elseif is_hover then
            helpers.SetColor({0.6, 0.6, 0.6, 1.0}) -- Brighter on hover
        else
            helpers.SetColor({0.5, 0.5, 0.5, 1.0}) -- Default thumb
        end
        components.DrawRoundedRect(bar_x, sb_y + thumb_offset, bar_w, THUMB_SIZE, 2, true)
        
        -- Click detection
        if ui_store.GetMouseClick() and mx >= bar_x and mx <= bar_x + bar_w and my >= sb_y and my <= sb_y + SB_SIZE then
            island_store.SetSbDragging(true)
            island_store.SetSbDragStartX(mx)
            island_store.SetSbScrollAtDragStart(math.min(scroll_x, max_scroll_x))
        end
        if island_store.GetSbDragging() then
            if (gfx.mouse_cap & 1) == 0 then island_store.SetSbDragging(false)
            else island_store.SetScrollOffsetX(math.max(0, math.min(max_scroll_x, island_store.GetSbScrollAtDragStart() + ((mx - island_store.GetSbDragStartX()) / grid_w) * total_beats))) end
        end
    end

    -- Vertical
    local scroll_y = island_store.GetScrollOffsetY()
    local TOTAL_PITCHES = 108
    local vsb_x, vsb_w = right_x + grid_w + LABEL_W, SB_SIZE
    local vsb_h = pr_h + (ve_h > 0 and ve_h or 0)
    local visible_rows = pr_h / math.max(1, piano_roll.PITCH_ROW_H)
    if visible_rows < TOTAL_PITCHES then
        local max_scroll_y = TOTAL_PITCHES - visible_rows
        -- Track
        helpers.SetColor(theme.colors.island_bg)
        gfx.rect(vsb_x, pr_y, vsb_w, vsb_h)

        local bar_h = math.max(14, vsb_h * (visible_rows / TOTAL_PITCHES))
        local track_h = vsb_h - bar_h
        local bar_y = pr_y + (math.min(scroll_y, max_scroll_y) / max_scroll_y) * track_h
        
        -- Thumb with hover/active states (opaque → fast path, avoids blit artifacts)
        local is_v_hover = mx >= vsb_x and mx <= vsb_x + vsb_w and my >= bar_y and my <= bar_y + bar_h
        if island_store.GetVsbDragging() then
            helpers.SetColor({0.25, 0.50, 0.85, 1.0}) -- Blue active when dragging
        elseif is_v_hover then
            helpers.SetColor({0.6, 0.6, 0.6, 1.0}) -- Brighter on hover
        else
            helpers.SetColor({0.5, 0.5, 0.5, 1.0}) -- Default thumb
        end
        components.DrawRoundedRect(vsb_x + thumb_offset, bar_y, THUMB_SIZE, bar_h, 2, true)
        
        -- Click detection
        if ui_store.GetMouseClick() and mx >= vsb_x and mx <= vsb_x + vsb_w and my >= bar_y and my <= bar_y + bar_h then
            island_store.SetVsbDragging(true)
            island_store.SetVsbDragStartY(my)
            island_store.SetVsbScrollAtDragStart(math.min(scroll_y, max_scroll_y))
        end
        if island_store.GetVsbDragging() then
            if (gfx.mouse_cap & 1) == 0 then island_store.SetVsbDragging(false)
            else island_store.SetScrollOffsetY(math.max(0, math.min(max_scroll_y, island_store.GetVsbScrollAtDragStart() + ((my - island_store.GetVsbDragStartY()) / vsb_h) * max_scroll_y))) end
        end
    end
end

return m
