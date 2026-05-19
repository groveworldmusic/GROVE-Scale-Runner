-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- GROVE Scale Runner: MIDI Island Input Dispatcher (Phase 5)
-- Paint/knife tool modes replace the legacy pointer/pencil/eraser dispatch.

local config = require("config")
local island_store = require("state.island")
local ui_store = require("state.ui")
local drag_store = require("state.drag")
local seq_store = require("state.sequencer")
local piano_roll = require("ui.piano-roll")
local timeline = require("ui.timeline")
local velocity = require("ui.velocity")

local m = {}

-- =========================================================
-- Right-click drag gating (module-local, per drag session)
-- =========================================================
local _rc_gate_active = false  -- true while right button held within grid

-- =========================================================
-- Time selection drag state (module-local, per drag session)
-- =========================================================
local _ts_dragging = false
local _ts_drag_start_beat = 0

function m.HandleKeyboard(char, prog_focused)
    local keyboard_consumed = false

    -- Quantize dialog open: block all keyboard input (Escape handled by DrawQuantizeDialog)
    if island_store.GetQuantizeDialogOpen() then
        return false
    end

    -- Progression undo/redo shortcuts when mouse is not in piano roll grid
    if prog_focused then
        if char == 346 then  -- Ctrl+Z (90 + 256)
            seq_store.HandleProgUndo()
            keyboard_consumed = true
        elseif char == 345 then  -- Ctrl+Y (89 + 256)
            seq_store.HandleProgRedo()
            keyboard_consumed = true
        end
    end

    -- Handle Escape for cancel drag
    if not keyboard_consumed and char == 27 and island_store.GetNoteDragActive() then
        piano_roll.CancelNoteDrag()
        keyboard_consumed = true
    end

    -- Handle piano roll keyboard shortcuts
    if not keyboard_consumed then
        local scroll_beat = island_store.GetScrollOffsetX()
        keyboard_consumed = piano_roll.HandleKeyboardShortcut(char, scroll_beat)
    end

    return keyboard_consumed
end

function m.HandleMouse(ctx)
    -- Block normal input when quantize dialog is open (dialog handles its own mouse)
    if island_store.GetQuantizeDialogOpen() then return false end

    local mx, my = gfx.mouse_x, gfx.mouse_y
    local click = ui_store.GetMouseClick()
    local last_cap = ui_store.GetLastMouseCap()
    local mwd = ui_store.ConsumeMouseWheelDelta()
    local click_consumed = false

    local tool_mode = island_store.GetToolMode()
    local notes = island_store.GetNotes()

    -- Transition detection
    local left_down = click  -- fresh left-click this frame (already computed by ui_store)
    local left_held = (gfx.mouse_cap & 1) == 1
    local right_down = (gfx.mouse_cap & 2) == 2 and (last_cap & 2) == 0
    local right_held = (gfx.mouse_cap & 2) == 2
    local right_release = (gfx.mouse_cap & 2) == 0 and (last_cap & 2) == 2
    local ctrl_held = (gfx.mouse_cap & 4) == 4

    -- Unpack layout from ctx
    local right_x = ctx.right_x
    local right_w = ctx.right_w
    local SB_SIZE = ctx.SB_SIZE
    local y = ctx.y
    local h = ctx.h
    local pr_y = ctx.pr_y
    local pr_h = ctx.pr_h
    local ve_y = ctx.ve_y
    local ve_h = ctx.ve_h
    local tl_h = ctx.tl_h
    local grid_w = ctx.grid_w
    local sb_y = ctx.sb_y
    local sb_h = ctx.sb_h

    -- 1. Check velocity collapse handle BEFORE piano roll
    if island_store.GetVelocityPanelExpanded() and velocity.IsOverCollapseHandle(mx, my, right_x, ve_y, right_w - SB_SIZE, ve_h) then
        if click then
            island_store.SetVelocityPanelExpanded(false)
            ui_store.ConsumeMouseClick()
            click_consumed = true
        end
    end

    -- 2. Timeline ruler click/drag -> time selection + seek
    if not click_consumed and mx >= right_x and mx < right_x + right_w
       and my >= y and my < y + tl_h then
        local grid_x = right_x + timeline.PITCH_LABEL_W
        if click then
            -- Start time selection drag
            _ts_dragging = true
            local beat = timeline.TimelineHitTest(mx, grid_x, island_store.GetScrollOffsetX(), island_store.GetZoomX())
            _ts_drag_start_beat = beat
            island_store.SetTimeSelectionStart(beat)
            island_store.SetTimeSelectionEnd(beat)
            island_store.SetPlaybackPos(beat)
            click_consumed = true
        elseif _ts_dragging and left_held then
            -- Update time selection end while dragging
            local beat = timeline.TimelineHitTest(mx, grid_x, island_store.GetScrollOffsetX(), island_store.GetZoomX())
            island_store.SetTimeSelectionEnd(beat)
            click_consumed = true
        end
        -- Time selection drag cleanup
        if not left_held then
            if _ts_dragging then
                -- Ensure start is min, end is max (defensive)
                local s = island_store.GetTimeSelectionStart()
                local e = island_store.GetTimeSelectionEnd()
                if s > e then
                    island_store.SetTimeSelectionStart(e)
                    island_store.SetTimeSelectionEnd(s)
                end
            end
            _ts_dragging = false
        end
    end

    -- =========================================================
    -- 3. Piano Roll Area — Tool Dispatch
    -- =========================================================
    local in_grid_area = mx >= right_x and mx < right_x + right_w - SB_SIZE
                      and my >= pr_y and my < pr_y + pr_h
    local grid_x = right_x + piano_roll.PITCH_LABEL_W
    local in_grid_body = in_grid_area and mx >= grid_x

    -- =========================================================
    -- 3b. Right-click gate (shared by paint and knife modes)
    -- =========================================================
    -- Track right-button state within grid for drag-vs-stationary gating.
    if right_down and in_grid_area then
        piano_roll.StartRightDragSweep(mx, my)
        _rc_gate_active = true
        click_consumed = true
    end
    if right_held and _rc_gate_active then
        piano_roll.UpdateRightDragSweep(mx, my, grid_x, pr_y,
            island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
            island_store.GetZoomX())
        click_consumed = true
    end
    if right_release and _rc_gate_active then
        _rc_gate_active = false
        if in_grid_area then
            local sweep_consumed = piano_roll.CommitRightDragSweep(mx, my, grid_x, pr_y,
                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                island_store.GetZoomX())
            if sweep_consumed then
                piano_roll.MarkNotesDirty()
                click_consumed = true
            else
                -- Stationary right-click (no sweep): try HandlePaintRightClick
                if in_grid_body then
                    if piano_roll.HandlePaintRightClick(mx, my, grid_x, pr_y,
                        island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                        island_store.GetZoomX()) then
                        piano_roll.MarkNotesDirty()
                        click_consumed = true
                    end
                end
            end
        end
    end
    -- Reset gate if right button released outside grid
    if right_release and _rc_gate_active and not in_grid_area then
        _rc_gate_active = false
        piano_roll.CancelRightDragSweep()
    end

    -- =========================================================
    -- 3c. Left-click dispatch (by tool mode)
    -- =========================================================
    if not click_consumed and in_grid_area then

        -- =========================================================
        -- TOOL DISPATCH (paint / knife)
        -- =========================================================
            if tool_mode == "paint" then
                -- ---- Left-click ----
                if left_down then
                    if in_grid_body then
                        local hit_idx = piano_roll.NoteBlockHitTest(mx, my, notes,
                            island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                            island_store.GetZoomX(), grid_x, pr_y)
                        if hit_idx then
                            -- Edge resize check: left edge first (higher priority for selection?)
                            if piano_roll.IsNoteLeftEdge(mx, my, notes, hit_idx, grid_x, pr_y,
                                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                island_store.GetZoomX()) then
                                piano_roll.StartNoteResize(mx, my, grid_x, pr_y,
                                    island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                    island_store.GetZoomX(), hit_idx, "left")
                            elseif piano_roll.IsNoteRightEdge(mx, my, notes, hit_idx, grid_x, pr_y,
                                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                island_store.GetZoomX()) then
                                piano_roll.StartNoteResize(mx, my, grid_x, pr_y,
                                    island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                    island_store.GetZoomX(), hit_idx, "right")
                            else
                                -- Body click: select + arm drag
                                piano_roll.HandlePaintClick(mx, my, grid_x, pr_y,
                                    island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                    island_store.GetZoomX(), ctrl_held, false)
                                piano_roll.ArmNoteDrag(hit_idx, mx, my)
                            end
                        else
                            -- Empty cell: Ctrl → lasso, no Ctrl → create note
                            if ctrl_held then
                                island_store.SetLassoActive(true)
                                island_store.SetLassoStartX(mx)
                                island_store.SetLassoStartY(my)
                                island_store.SetLassoEndX(mx)
                                island_store.SetLassoEndY(my)
                            else
                                piano_roll.HandlePaintClick(mx, my, grid_x, pr_y,
                                    island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                    island_store.GetZoomX(), ctrl_held, false)
                                piano_roll.MarkNotesDirty()
                            end
                        end
                    end
                    click_consumed = true
                end

                -- Ctrl+drag lasso initiation (fires even without left_down,
                -- e.g. Ctrl pressed mid-drag or when initial click is on a note)
                if not island_store.GetLassoActive() and not island_store.GetNoteDragActive()
                   and ctrl_held and left_held and in_grid_body then
                    island_store.SetLassoActive(true)
                    island_store.SetLassoStartX(mx)
                    island_store.SetLassoStartY(my)
                    island_store.SetLassoEndX(mx)
                    island_store.SetLassoEndY(my)
                end

                -- Armed drag check (skip when lasso is active)
                if not island_store.GetLassoActive() and not island_store.GetNoteDragActive() and left_held then
                    if piano_roll.CheckAndStartDrag(mx, my, grid_x, pr_y,
                        island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                        island_store.GetZoomX()) then
                        click_consumed = true
                        piano_roll.MarkNotesDirty()
                    end
                elseif not island_store.GetNoteDragActive() and not left_held then
                    piano_roll.DisarmNoteDrag()
                end

                -- Active drag/resize
                if island_store.GetNoteDragActive() then
                    if left_held then
                        if island_store.GetNoteResizeEdge() then
                            piano_roll.UpdateNoteResize(mx, my, grid_x, pr_y,
                                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                island_store.GetZoomX())
                        else
                            piano_roll.UpdateNoteDrag(mx, my, grid_x, pr_y,
                                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                island_store.GetZoomX())
                        end
                    else
                        if island_store.GetNoteResizeEdge() then
                            piano_roll.CommitNoteResize(mx, my, grid_x, pr_y,
                                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                island_store.GetZoomX())
                        else
                            piano_roll.CommitNoteDrag(mx, my, grid_x, pr_y,
                                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                island_store.GetZoomX())
                        end
                        piano_roll.MarkNotesDirty()
                    end
                    click_consumed = true
                end
                if island_store.GetLassoActive() then click_consumed = true end

            elseif tool_mode == "knife" then
                -- Knife tool: split note at click position
                if left_down then
                    if in_grid_body then
                        if piano_roll.HandleKnifeClick(mx, my, grid_x, pr_y,
                            island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                            island_store.GetZoomX()) then
                            piano_roll.MarkNotesDirty()
                        end
                    end
                    click_consumed = true
                end

            elseif tool_mode == "eraser" then
                -- Eraser tool: delete note on left click
                if left_down then
                    if in_grid_body then
                        if piano_roll.HandlePaintRightClick(mx, my, grid_x, pr_y,
                            island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                            island_store.GetZoomX()) then
                            piano_roll.MarkNotesDirty()
                        end
                    end
                    click_consumed = true
                end
            end
    end

    -- =========================================================
    -- 5. Velocity editor
    -- =========================================================
    local in_vel_zone = mx >= right_x and mx < right_x + right_w - SB_SIZE
                    and my >= ve_y and my < ve_y + ve_h
    if not click_consumed and (in_vel_zone or velocity.IsDragging()) then
        local vel_grid_x = right_x + piano_roll.PITCH_LABEL_W
        if velocity.HandleVelocityMouse(mx, my, vel_grid_x, ve_y, ve_h,
            island_store.GetScrollOffsetX(), island_store.GetZoomX(), click, left_held) then
            click_consumed = true
            piano_roll.MarkNotesDirty()
        end
    end

    -- =========================================================
    -- 6. Lasso update
    -- =========================================================
    if island_store.GetLassoActive() then
        if not left_held then
            local indices = piano_roll.GetNotesInRect(island_store.GetLassoStartX(), island_store.GetLassoStartY(),
                island_store.GetLassoEndX(), island_store.GetLassoEndY(), grid_x, pr_y,
                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(), island_store.GetZoomX())
            local sel = {}
            for _, idx in ipairs(indices) do sel[idx] = true end
            island_store.SetSelectedIndices(sel)
            island_store.SetLassoActive(false)
        else
            island_store.SetLassoEndX(mx)
            island_store.SetLassoEndY(my)
        end
        click_consumed = true
    end

    -- =========================================================
    -- 7. Wheel handling
    -- =========================================================
    if mwd ~= 0 and mx >= right_x and mx < right_x + right_w then
        local grid_edge = right_x + piano_roll.PITCH_LABEL_W
        if my >= y and my < y + tl_h then
            island_store.SetZoomX(piano_roll.HandleZoomX(mwd, island_store.GetZoomX()))
        elseif my >= pr_y and my < pr_y + pr_h then
            if mx >= grid_edge then
                if ctrl_held then
                    island_store.SetZoomX(piano_roll.HandleZoomX(mwd, island_store.GetZoomX()))
                elseif (gfx.mouse_cap & 16) == 16 then -- Alt
                    piano_roll.SetPitchRowH(piano_roll.HandleZoomVertical(mwd, piano_roll.PITCH_ROW_H))
                else
                    island_store.SetScrollOffsetY(piano_roll.HandleMouseWheelVertical(mwd, island_store.GetScrollOffsetY()))
                end
            else
                island_store.SetScrollOffsetY(piano_roll.HandleMouseWheelVertical(mwd, island_store.GetScrollOffsetY()))
            end
        end
    end

    return click_consumed
end

return m
