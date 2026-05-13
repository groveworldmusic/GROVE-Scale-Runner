-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- GROVE Scale Runner: Drag State Store
-- Encapsulates drag-and-drop state with getters/setters.
-- Extracted from config.state.drag.
local drag_state = {
    is_dragging = false,
    source_degree = -1,
    source_slot_idx = -1,
    pending_degree = nil,
    pending_slot_idx = nil,
    start_x = 0,
    start_y = 0,
    x = 0,
    y = 0,
}

local m = {}

function m.Init(defaults)
    if defaults.drag then
        for k, v in pairs(defaults.drag) do drag_state[k] = v end
    end
end

-- Getters
function m.GetIsDragging() return drag_state.is_dragging end
function m.GetSourceDegree() return drag_state.source_degree end
function m.GetSourceSlotIdx() return drag_state.source_slot_idx end
function m.GetPendingDegree() return drag_state.pending_degree end
function m.GetPendingSlotIdx() return drag_state.pending_slot_idx end
function m.GetStartX() return drag_state.start_x end
function m.GetStartY() return drag_state.start_y end
function m.GetX() return drag_state.x end
function m.GetY() return drag_state.y end

-- Setters
function m.SetIsDragging(v) drag_state.is_dragging = v end
function m.SetSourceDegree(v) drag_state.source_degree = v end
function m.SetSourceSlotIdx(v) drag_state.source_slot_idx = v end
function m.SetPendingDegree(v) drag_state.pending_degree = v end
function m.SetPendingSlotIdx(v) drag_state.pending_slot_idx = v end
function m.SetStartX(v) drag_state.start_x = v end
function m.SetStartY(v) drag_state.start_y = v end
function m.SetX(v) drag_state.x = v end
function m.SetY(v) drag_state.y = v end

-- Reset all drag state (called when drag ends)
function m.Reset()
    drag_state.is_dragging = false
    drag_state.source_degree = -1
    drag_state.source_slot_idx = -1
    drag_state.pending_degree = nil
    drag_state.pending_slot_idx = nil
end

return m
