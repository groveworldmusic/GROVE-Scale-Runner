-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
local island_store = require("state.island")
local ui_store = require("state.ui")
local drag_store = require("state.drag")
local piano_roll = require("ui.piano-roll")
local timeline = require("ui.timeline")
local velocity = require("ui.velocity")

local m = {}

function m.HandleKeyboard(char)
    local tool_mode = island_store.GetToolMode()
    local keyboard_consumed = false

    -- Handle Escape for cancel drag
    if char == 27 and island_store.GetNoteDragActive() then
        piano_roll.CancelNoteDrag()
        keyboard_consumed = true
    end

    -- Handle piano roll keyboard shortcuts (pointer/eraser mode)
    if not keyboard_consumed and (tool_mode == "pointer" or tool_mode == "eraser") then
        local scroll_beat = island_store.GetScrollOffsetX()
        keyboard_consumed = piano_roll.HandleKeyboardShortcut(char, scroll_beat)
    end
    
    return keyboard_consumed
end

function m.HandleMouse(ctx)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local click = ui_store.GetMouseClick()
    local last_cap = ui_store.GetLastMouseCap()
    local right_click = (gfx.mouse_cap & 2) == 2 and (last_cap & 2) == 0
    local mwd = ui_store.ConsumeMouseWheelDelta()
    local click_consumed = false
    
    local tool_mode = island_store.GetToolMode()
    local notes = island_store.GetNotes()
    
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

    -- Timeline ruler click -> seek
    if not click_consumed and mx >= right_x and mx < right_x + right_w
       and my >= y and my < y + tl_h then
        if click then
            local grid_x = right_x + timeline.PITCH_LABEL_W
            local beat = timeline.TimelineHitTest(mx, grid_x, island_store.GetScrollOffsetX(), island_store.GetZoomX())
            island_store.SetPlaybackPos(beat)
            click_consumed = true
        end
    end

    -- Piano roll left-click -> route by tool mode
    if not click_consumed and mx >= right_x and mx < right_x + right_w - SB_SIZE
       and my >= pr_y and my < pr_y + pr_h then
        local grid_x = right_x + piano_roll.PITCH_LABEL_W
        local in_grid = mx >= grid_x

        if tool_mode == "pointer" then
            if click then
                if island_store.GetLassoActive() then island_store.SetLassoActive(false) end
                if in_grid then
                    local hit_idx = piano_roll.NoteBlockHitTest(mx, my, notes,
                        island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                        island_store.GetZoomX(), grid_x, pr_y)
                    if hit_idx then
                        if piano_roll.IsNoteRightEdge(mx, my, notes, hit_idx, grid_x, pr_y,
                            island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                            island_store.GetZoomX()) then
                            piano_roll.StartNoteResize(mx, my, grid_x, pr_y,
                                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                island_store.GetZoomX(), hit_idx)
                        else
                            piano_roll.HandleMouseClick(mx, my, grid_x, pr_y,
                                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                                island_store.GetZoomX(), (gfx.mouse_cap & 32) ~= 0)
                            piano_roll.ArmNoteDrag(hit_idx, mx, my)
                        end
                    else
                        island_store.SetLassoActive(true)
                        island_store.SetLassoStartX(mx)
                        island_store.SetLassoStartY(my)
                        island_store.SetLassoEndX(mx)
                        island_store.SetLassoEndY(my)
                    end
                end
                click_consumed = true
            end

            -- Armed drag check
            if not island_store.GetNoteDragActive() and (gfx.mouse_cap & 1) == 1 then
                if piano_roll.CheckAndStartDrag(mx, my, grid_x, pr_y,
                    island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                    island_store.GetZoomX()) then
                    click_consumed = true
                    piano_roll.MarkNotesDirty()
                end
            elseif not island_store.GetNoteDragActive() and (gfx.mouse_cap & 1) == 0 then
                piano_roll.DisarmNoteDrag()
            end

            -- Active drag/resize
            if island_store.GetNoteDragActive() then
                if (gfx.mouse_cap & 1) == 1 then
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

        elseif tool_mode == "pencil" then
            if click and in_grid then
                piano_roll.HandlePencilClick(mx, my, grid_x, pr_y,
                    island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                    island_store.GetZoomX())
                piano_roll.MarkNotesDirty()
                click_consumed = true
            end
        elseif tool_mode == "eraser" then
            if click and in_grid then
                piano_roll.HandleEraserClick(mx, my, grid_x, pr_y,
                    island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(),
                    island_store.GetZoomX())
                piano_roll.MarkNotesDirty()
                click_consumed = true
            end
        end
    end

    -- Right-click mute
    if not click_consumed and mx >= right_x and mx < right_x + right_w - SB_SIZE
       and my >= pr_y and my < my + pr_h then
        if right_click then
            local grid_x = right_x + piano_roll.PITCH_LABEL_W
            if piano_roll.HandleRightClickMute(mx, my, grid_x, pr_y,
                island_store.GetScrollOffsetY(), island_store.GetScrollOffsetX(), island_store.GetZoomX()) then
                click_consumed = true
                piano_roll.MarkNotesDirty()
            end
        end
    end

    -- Velocity editor
    local in_vel_zone = mx >= right_x and mx < right_x + right_w - SB_SIZE
                    and my >= ve_y and my < ve_y + ve_h
    if not click_consumed and (in_vel_zone or velocity.IsDragging()) then
        local grid_x = right_x + piano_roll.PITCH_LABEL_W
        if velocity.HandleVelocityMouse(mx, my, grid_x, ve_y, ve_h,
            island_store.GetScrollOffsetX(), island_store.GetZoomX(), click, (gfx.mouse_cap & 1) == 1) then
            click_consumed = true
            piano_roll.MarkNotesDirty()
        end
    end

    -- Lasso update
    if island_store.GetLassoActive() then
        if (gfx.mouse_cap & 1) == 0 then
            local grid_x = right_x + piano_roll.PITCH_LABEL_W
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

    -- Wheel handling
    if mwd ~= 0 and mx >= right_x and mx < right_x + right_w then
        local grid_edge = right_x + piano_roll.PITCH_LABEL_W
        if my >= y and my < y + tl_h then
            island_store.SetZoomX(piano_roll.HandleZoomX(mwd, island_store.GetZoomX()))
        elseif my >= pr_y and my < pr_y + pr_h then
            if mx >= grid_edge then
                if (gfx.mouse_cap & 4) == 4 then -- Ctrl
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
