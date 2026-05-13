-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik on the beat
-- GROVE Scale Runner: Progression CRUD — add, remove, swap, clear, and query operations
local seq_store = require("state.sequencer")

local progression = {}

-- Assign slot at index and trigger flash highlight
function progression.Add(idx, slot)
    seq_store.SetProgressionEntry(idx, slot)
    seq_store.SetSlotFlashIdx(idx)
    seq_store.SetSlotFlashTimer(10)
end

-- Remove slot at index (set to nil)
function progression.Remove(idx)
    seq_store.SetProgressionEntry(idx, nil)
end

-- Swap two progression slots
function progression.Swap(a, b)
    local temp = seq_store.GetProgressionEntry(a)
    seq_store.SetProgressionEntry(a, seq_store.GetProgressionEntry(b))
    seq_store.SetProgressionEntry(b, temp)
end

-- Clear all 16 progression slots
function progression.Clear()
    seq_store.ClearProgression()
end

-- Find the last filled slot index (16 → 1), returns 0 if empty
function progression.GetLastFilled()
    for i = 16, 1, -1 do
        if seq_store.GetProgressionEntry(i) then return i end
    end
    return 0
end

return progression
