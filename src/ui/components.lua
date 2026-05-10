local config = require("config")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local midi = require("core.midi")
local format = require("ui.format")
local colors = require("ui.colors")
local progression = require("core.progression")
local buttons = require("ui.buttons")
local paginator = require("ui.paginator")
local dropdown = require("ui.dropdown")

local components = {}

-- Cached scale note tables for DrawPianoKeyboard (Issue 13)
local cached_scale_root = nil
local cached_scale_idx = nil
local cached_scale_notes = {}
local cached_note_to_degree = {}

-- QWERTY key labels for degrees 1-7 (base octave)
local DEGREE_KEY_LABELS = {"Q", "W", "E", "R", "T", "Y", "U"}



-- Shared piano keyboard layout constants
-- Used by both the full-view GFX piano (DrawPianoKeyboard) and compact LICE piano
components.PIANO_LAYOUT = {
    -- White key count per octave (C D E F G A B)
    white_keys_per_octave = 7,
    -- Black key count per octave (C# D# F# G# A#)
    black_keys_per_octave = 5,
    -- Black key width/height as fraction of white key width / total height
    black_key_width_ratio = 0.65,
    black_key_height_ratio = 0.65,
    -- Note indices within an octave that are white keys (1=C, 3=D, ..., 12=B)
    white_key_note_indices = {1, 3, 5, 6, 8, 10, 12},
    -- Black key spec: {idx=note_index, pos=position_of_white_key_to_the_left}
    black_key_specs = {
        {idx=2, pos=1},   -- C# between C (pos 1) and D
        {idx=4, pos=2},   -- D# between D (pos 2) and E
        {idx=7, pos=4},   -- F# between F (pos 4) and G
        {idx=9, pos=5},   -- G# between G (pos 5) and A
        {idx=11, pos=6},  -- A# between A (pos 6) and B
    },
    -- Octave range: C2 to C8
    start_note = 36,   -- MIDI note C2 (leftmost key)
    end_note = 108,    -- MIDI note C8 (rightmost key)
    num_keys = 73,     -- Total keys from C2 through C8 inclusive
}

function components.DrawIsland(x, y, w, h, title, font_size)
    helpers.SetColor(theme.colors.island_bg)
    components.DrawRoundedRect(x, y, w, h, 10, true)
    
    if title then
        helpers.SetColor(theme.colors.text_dim)
        gfx.setfont(1, "Calibri", font_size or 12)
        local tw, th = gfx.measurestr(title)
        gfx.x, gfx.y = x + (w - tw)/2, y + math.floor((font_size or 12) * 0.5)
        gfx.drawstr(title)
    end
end

function components.DrawRoundedRect(x, y, w, h, r, fill)
    if r <= 0 then gfx.rect(x,y,w,h,1) return end
    r = math.min(r, w/2, h/2)
    
    if fill then
        gfx.circle(x + r, y + r, r, 1, 1)
        gfx.circle(x + w - r, y + r, r, 1, 1)
        gfx.circle(x + r, y + h - r, r, 1, 1)
        gfx.circle(x + w - r, y + h - r, r, 1, 1)
        gfx.rect(x + r, y, math.max(0, w - r * 2) + 1, h + 1, 1)
        gfx.rect(x, y + r, w + 1, math.max(0, h - r * 2) + 1, 1)
    else
        gfx.roundrect(x, y, w, h, r, 1)
    end
end

-- Extracted: background, glow, progress bar, flash overlay
local function DrawSlotBackground(global_idx, x, y, w, h, slot, play, seq)
    -- Background Glow for playing slot
    if play then
        helpers.SetColor(theme.colors.slot_playing, 0.2)
        components.DrawRoundedRect(x-4, y-4, w+8, h+8, 12, true)
    end

    if slot then
        local slot_color = colors.DegreeColor(slot.degree)
        helpers.SetColor(slot_color)
        if play then helpers.SetColor(theme.colors.slot_playing, 0.4) end
        components.DrawRoundedRect(x, y, w, h, 8, true)
    else
        helpers.SetColor(theme.colors.text_dim, 0.2)
        if play then helpers.SetColor(theme.colors.slot_playing, 0.4) end
        components.DrawRoundedRect(x, y, w, h, 8, false)

        -- Empty state hint (only when not dragging)
        if not config.state.drag.is_dragging then
            helpers.SetColor(theme.colors.text_dim, 0.15)
            gfx.setfont(1, "Calibri", math.floor(h * 0.3))
            local pw, ph = gfx.measurestr("+")
            gfx.x, gfx.y = x + (w - pw) / 2, y + (h - ph) / 2
            gfx.drawstr("+")
        end
    end

    -- Slot flash highlight on drop
    local flash = config.state.slot_flash
    if flash.idx == global_idx and flash.timer > 0 then
        helpers.SetColor(theme.colors.slot_playing, (flash.timer / 10) * 0.5)
        components.DrawRoundedRect(x, y, w, h, 8, true)
        flash.timer = flash.timer - 1
        if flash.timer <= 0 then
            flash.idx = -1
            flash.timer = 0
        end
    end

    -- PROGRESS BAR OVERLAY
    if play and (seq.progress or 0) > 0 then
        helpers.SetColor(theme.colors.slot_playing, 0.4)
        local prog_w = math.floor(w * seq.progress)
        components.DrawRoundedRect(x, y, prog_w, h, 8, true)
    end
end

-- Extracted: note name, roman numeral, slot number
local function DrawSlotLabel(global_idx, x, y, w, h, slot)
    -- Slot number (top-left corner)
    helpers.SetColor(theme.colors.text_dim, 0.3)
    gfx.setfont(1, "Calibri", math.floor(h * 0.15))
    local num_str = tostring(global_idx)
    gfx.x, gfx.y = x + 4, y + 2
    gfx.drawstr(num_str)

    if slot then
        local label = format.ChordLabel({root_index=slot.root_index, scale_index=slot.scale_index, degree=slot.degree, octave=slot.octave, chord_mode_index=slot.chord_mode_index})
        
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", math.floor(h * 0.35))
        local nw, nh = gfx.measurestr(label)
        gfx.x, gfx.y = x+(w-nw)/2, y + (h/2) - nh
        gfx.drawstr(label)
        
        gfx.setfont(1, "Calibri", math.floor(h * 0.25))
        local deg = format.RomanNumeral(slot.degree)
        local dw = gfx.measurestr(deg)
        gfx.x, gfx.y = x+(w-dw)/2, y + (h/2) + 6
        gfx.drawstr(deg)
    end
end

-- Extracted: hover, tooltips, right-click delete, drag-start, drag-drop swap/new
local function HandleSlotInteraction(global_idx, x, y, w, h, slot, hover)
    if not hover then return end

    helpers.SetColor({1,1,1,0.1})
    components.DrawRoundedRect(x, y, w, h, 8, true)

    -- Drag target highlight: match dragged item's grade color
    if config.state.drag.is_dragging then
        local drag_deg = config.state.drag.source_degree
        if drag_deg == -1 and config.state.drag.source_slot_idx ~= -1 then
            local src = config.state.progression[config.state.drag.source_slot_idx]
            if src then drag_deg = src.degree end
        end
        local highlight = colors.DegreeColor(drag_deg)
        helpers.SetColor(highlight, 0.3)
        components.DrawRoundedRect(x, y, w, h, 8, true)
    end

    -- RIGHT CLICK TO DELETE (on fresh click-down only)
    if (gfx.mouse_cap & 2) == 2 and (config.state.last_mouse_cap & 2) == 0 then
        progression.Remove(global_idx)
    end

    -- CLICK + DRAG: track pending, start drag only after 8px threshold
    if (gfx.mouse_cap & 1) == 1 and not config.state.drag.is_dragging and not config.state.slider_dragging and slot then
        if not config.state.drag.pending_slot_idx then
            config.state.drag.pending_slot_idx = global_idx
            config.state.drag.start_x, config.state.drag.start_y = gfx.mouse_x, gfx.mouse_y
        elseif config.state.drag.pending_slot_idx == global_idx then
            local dx = gfx.mouse_x - config.state.drag.start_x
            local dy = gfx.mouse_y - config.state.drag.start_y
            if math.sqrt(dx*dx + dy*dy) >= 8 then
                config.state.drag.is_dragging = true
                config.state.drag.source_slot_idx = global_idx
                config.state.drag.pending_slot_idx = nil
            end
        end
    end

    -- Clear pending if mouse released without drag
    if (gfx.mouse_cap & 1) == 0 and config.state.drag.pending_slot_idx == global_idx then
        -- LEFT CLICK TO PLAY NOTE (no drag happened)
        if slot then
            midi.TriggerChord(slot.degree, true, slot)
            midi.TriggerChord(slot.degree, false, slot)
        end
        config.state.drag.pending_slot_idx = nil
    end

    -- Drop Logic (Left Release after drag)
    if config.state.drag.is_dragging and (gfx.mouse_cap & 1) == 0 then
        if config.state.drag.source_slot_idx ~= -1 and config.state.drag.source_slot_idx ~= global_idx then
            -- SWAP instead of overwrite
            progression.Swap(config.state.drag.source_slot_idx, global_idx)
        elseif config.state.drag.source_degree ~= -1 then
            -- NEW FROM PAD
            progression.Add(global_idx, { 
                degree = config.state.drag.source_degree, 
                root_index = config.state.root_index, 
                scale_index = config.state.scale_index, 
                octave = config.state.octave, 
                chord_mode_index = config.state.chord_mode_index 
            })
        end
        
        -- Cleanup immediately so DrawDragPreview doesn't see stale state
        config.state.drag.is_dragging = false
        config.state.drag.source_degree = -1
        config.state.drag.source_slot_idx = -1
        config.state.drag.pending_degree = nil
    end

    if not config.state.drag.is_dragging then
        if slot then
            local label = format.ChordLabel({root_index=slot.root_index, scale_index=slot.scale_index, degree=slot.degree, octave=slot.octave, chord_mode_index=slot.chord_mode_index})
            helpers.DrawTooltip("Slot " .. global_idx .. ": " .. label, 11)
        else
            helpers.DrawTooltip("Slot " .. global_idx .. " — Empty", 11)
        end
    end
end

function components.DrawProgressionSlot(global_idx, x, y, w, h)
    local slot = config.state.progression[global_idx]
    local seq = config.state.sequencer
    local play = seq.is_playing and seq.current_step == global_idx
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    
    DrawSlotBackground(global_idx, x, y, w, h, slot, play, seq)
    DrawSlotLabel(global_idx, x, y, w, h, slot)
    HandleSlotInteraction(global_idx, x, y, w, h, slot, hover)

    -- Cleanup: clear pending_slot_idx if mouse released outside slot bounce zone
    if (gfx.mouse_cap & 1) == 0 and not config.state.drag.is_dragging and not hover then
        config.state.drag.pending_slot_idx = nil
    end
end

function components.DrawPianoKeyboard(x, y, w, h, font_size)
    local white_w = math.floor(w / components.PIANO_LAYOUT.white_keys_per_octave)
    -- Center keys horizontally if width isn't evenly divisible by 7
    local total_keys_w = white_w * components.PIANO_LAYOUT.white_keys_per_octave
    local slack = w - total_keys_w
    local x_off = x + math.floor(slack / 2)
    
    local black_w = math.floor(white_w * components.PIANO_LAYOUT.black_key_width_ratio)
    local black_h = math.floor(h * components.PIANO_LAYOUT.black_key_height_ratio)
    local octave_w = components.PIANO_LAYOUT.white_keys_per_octave * white_w
    
    local mx, my = gfx.mouse_x, gfx.mouse_y
    
    -- Cached scale note sets (Issue 13): only recompute when root/scale changes
    if cached_scale_root ~= config.state.root_index or cached_scale_idx ~= config.state.scale_index then
        cached_scale_notes = {}
        cached_note_to_degree = {}
        local intervals = config.SCALES[config.state.scale_index].intervals
        for degree, interval in ipairs(intervals) do
            local note_idx = ((config.state.root_index - 1 + interval) % 12) + 1
            cached_scale_notes[note_idx] = true
            cached_note_to_degree[note_idx] = degree
        end
        cached_scale_root = config.state.root_index
        cached_scale_idx = config.state.scale_index
    end
    local scale_notes = cached_scale_notes
    local note_to_degree = cached_note_to_degree

    -- Pre-compute active note pitch-class lookup (Issue 18): avoids O(N·M) inner loop
    local active_mod12 = {}
    for midi_note, _ in pairs(config.state.active_notes) do
        active_mod12[(midi_note % 12) + 1] = true
    end
    
    -- Draw White Keys first
    for i, wk in ipairs(components.PIANO_LAYOUT.white_key_note_indices) do
        local wx = x_off + (i-1) * white_w
        local is_root = (config.state.root_index == wk)
        local in_scale = scale_notes[wk]
        
        if is_root then
            helpers.SetColor(theme.colors.btn_active)
            components.DrawRoundedRect(wx, y, white_w - 2, h, 4, true)
        else
            helpers.SetColor(theme.colors.piano_white)
            components.DrawRoundedRect(wx, y, white_w - 2, h, 4, true)
            -- Bottom edge indicator for scale notes (grade-colored)
            if in_scale then
                local deg = note_to_degree[wk]
                helpers.SetColor(colors.DegreeColor(deg), 0.7)
                gfx.rect(wx + 4, y + h - 5, white_w - 10, 3, 1)
            end
        end
        
        helpers.SetColor(is_root and theme.colors.text or theme.colors.text_dark)
        gfx.setfont(1, "Calibri", font_size or 12)
        local n = config.NOTE_NAMES[wk]
        local nw, nh = gfx.measurestr(n)
        gfx.x, gfx.y = wx + (white_w - nw)/2, y + h - nh - 10
        gfx.drawstr(n)
        
        -- Active note glow (Issue 18): O(1) lookup via pre-computed pitch-class set
        if not is_root and active_mod12[wk] then
            local deg = note_to_degree[wk]
            local glow = deg and colors.DegreeColor(deg) or {1, 1, 1, 0.3}
            helpers.SetColor(glow, 0.2)
            components.DrawRoundedRect(wx, y, white_w - 2, h, 4, true)
        end
    end
    
    -- Draw Black Keys on top with text
    for _, bk in ipairs(components.PIANO_LAYOUT.black_key_specs) do
        local bx = x_off + (bk.pos * white_w) - black_w/2
        local is_root = (config.state.root_index == bk.idx)
        local in_scale = scale_notes[bk.idx]
        
        if is_root then
            helpers.SetColor(theme.colors.btn_active)
            components.DrawRoundedRect(bx, y, black_w, black_h, 3, true)
        else
            helpers.SetColor(theme.colors.piano_black)
            components.DrawRoundedRect(bx, y, black_w, black_h, 3, true)
            -- Bottom edge indicator for scale notes (grade-colored)
            if in_scale then
                local deg = note_to_degree[bk.idx]
                helpers.SetColor(colors.DegreeColor(deg), 0.7)
                gfx.rect(bx + 3, y + black_h - 4, black_w - 6, 2, 1)
            end
        end
        
        -- Drawing text for black keys
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", font_size or 12)
        local n = config.NOTE_NAMES[bk.idx]
        local nw, nh = gfx.measurestr(n)
        gfx.x, gfx.y = bx + (black_w - nw)/2, y + black_h - nh - 10
        gfx.drawstr(n)
        
        -- Active note glow for black keys (Issue 18): O(1) lookup
        if not is_root and active_mod12[bk.idx] then
            local deg = note_to_degree[bk.idx]
            local glow = deg and colors.DegreeColor(deg) or {1, 1, 1, 0.4}
            helpers.SetColor(glow, 0.3)
            components.DrawRoundedRect(bx, y, black_w, black_h, 3, true)
        end
    end
    
    
    -- Input Handling
    if config.state.mouse_click then
        local clicked_idx = 0
        for _, bk in ipairs(components.PIANO_LAYOUT.black_key_specs) do
            local bx = x_off + (bk.pos * white_w) - black_w/2
            if mx >= bx and mx <= bx + black_w and my >= y and my <= y + black_h then clicked_idx = bk.idx end
        end
        if clicked_idx == 0 then
                for i, wk in ipairs(components.PIANO_LAYOUT.white_key_note_indices) do
                local wx = x_off + (i-1) * white_w
                if mx >= wx and mx <= wx + white_w and my >= y and my <= y + h then clicked_idx = wk end
            end
        end
        if clicked_idx > 0 then config.state.root_index = clicked_idx end
    end
end

function components.DrawScalePad(x, y, w, h, degree, main_font_size, sub_font_size, total_degrees)
    local disabled = total_degrees and degree > total_degrees
    local hover = not disabled and gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    local label = format.ChordLabel({root_index=config.state.root_index, scale_index=config.state.scale_index, degree=degree, octave=config.state.octave, chord_mode_index=config.state.chord_mode_index})
    local roman = format.RomanNumeral(degree)
    
    local active = false
    if not disabled then
        for _, state in pairs(config.state.key_states) do if state.is_pressed and config.VKEY_MAP[state.code].deg == degree then active = true break end end
        if config.state.mouse_pad_state.active_degree == degree then active = true end
    end

    -- Flash trigger on pad activation
    if degree >= 1 and degree <= 7 then
        local prev = config.state.pad_flash.prev_active[degree]
        if active and not prev then
            config.state.pad_flash.degree = degree
            config.state.pad_flash.timer = 10
        end
        config.state.pad_flash.prev_active[degree] = active
    end

    -- Base
    if disabled then
        helpers.SetColor({0.3, 0.3, 0.3, 0.35})
    else
        helpers.SetColor(colors.DegreeColor(degree), active and 1 or 0.9)
    end
    components.DrawRoundedRect(x, y, w, h, 10, true)
    
    if hover and not disabled then
        helpers.SetColor({1, 1, 1, 0.15})
        components.DrawRoundedRect(x, y, w, h, 10, true)
        
        -- Bug fix: only start drag after moving 8px (distinguish click from drag)
        if (gfx.mouse_cap & 1) == 1 and not config.state.drag.is_dragging and not config.state.slider_dragging then
            if not config.state.drag.pending_degree then
                config.state.drag.pending_degree = degree
                config.state.drag.start_x, config.state.drag.start_y = gfx.mouse_x, gfx.mouse_y
            else
                local dx = gfx.mouse_x - config.state.drag.start_x
                local dy = gfx.mouse_y - config.state.drag.start_y
                if math.sqrt(dx*dx + dy*dy) >= 8 then
                    config.state.drag.is_dragging = true
                    config.state.drag.source_degree = config.state.drag.pending_degree
                    -- Only release pad-held notes when drag starts (Issue 5)
                    for _, n in ipairs(config.state.mouse_pad_state.midi_notes) do
                        midi.SendMidi(n, false)
                    end
                    config.state.mouse_pad_state.midi_notes = {}
                end
            end
        end

        if not config.state.drag.is_dragging then
            local key_label = DEGREE_KEY_LABELS[degree]
            helpers.DrawTooltip(key_label and (roman .. " (" .. key_label .. ")") or roman, 11)
        end
    end
    
    -- Clear pending drag if mouse released
    if (gfx.mouse_cap & 1) == 0 and config.state.drag.pending_degree then
        config.state.drag.pending_degree = nil
    end
    
    if disabled then
        helpers.SetColor({0.5, 0.5, 0.5, 0.6})
    else
        helpers.SetColor(theme.colors.text)
    end
    gfx.setfont(1, "Calibri", main_font_size or 18)
    local cw, ch = gfx.measurestr(label)
    gfx.x, gfx.y = x + (w-cw)/2, y + (h/2) - ch
    gfx.drawstr(label)
    
    gfx.setfont(1, "Calibri", sub_font_size or 14)
    local rw = gfx.measurestr(roman)
    gfx.x, gfx.y = x + (w-rw)/2, y + (h/2) + 4
    gfx.drawstr(roman)

    -- Keyboard shortcut hint
    local key_label = DEGREE_KEY_LABELS[degree]
    if key_label and not disabled then
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", sub_font_size or 14)
        local kw = gfx.measurestr(key_label)
        gfx.x, gfx.y = x + w - kw - 4, y + 2
        gfx.drawstr(key_label)
    end

    if not disabled and config.state.mouse_click and hover then
        if config.state.mouse_pad_state.active_degree ~= degree then
            config.state.mouse_pad_state.active_degree = degree
            config.state.mouse_pad_state.midi_notes = midi.TriggerChord(degree, true)
        end
    elseif not disabled and config.state.mouse_pad_state.active_degree == degree and (gfx.mouse_cap & 1) == 0 then
        -- Only turn off mouse-pad notes, not all notes (avoids killing QWERTY-held notes)
        for _, n in ipairs(config.state.mouse_pad_state.midi_notes) do
            midi.SendMidi(n, false)
        end
        config.state.mouse_pad_state.midi_notes = {}
        config.state.mouse_pad_state.active_degree = -1
    end

    -- Flash overlay on top of everything
    if config.state.pad_flash.degree == degree and config.state.pad_flash.timer > 0 then
        local alpha = (config.state.pad_flash.timer / 10) * 0.4
        helpers.SetColor({1, 1, 1, alpha})
        components.DrawRoundedRect(x, y, w, h, 10, true)
        config.state.pad_flash.timer = config.state.pad_flash.timer - 1
        if config.state.pad_flash.timer == 0 then
            config.state.pad_flash.degree = -1
        end
    end
end

function components.DrawDragPreview(w, h)
    if (gfx.mouse_cap & 1) == 0 and config.state.drag.is_dragging then
        config.state.drag.is_dragging = false
        config.state.drag.source_degree = -1
        config.state.drag.source_slot_idx = -1
        config.state.drag.pending_degree = nil
        config.state.drag.pending_slot_idx = nil
    end
    if not config.state.drag.is_dragging then return end

    -- Scale the original pad/slot size to a compact preview maintaining aspect ratio
    local scale = gfx.w / 39914
    local max_preview_w = math.min(100, math.floor(6000 * scale))
    local max_preview_h = math.min(80, math.floor(5000 * scale))
    local cw, ch
    if w / h > max_preview_w / max_preview_h then
        cw = max_preview_w
        ch = math.floor(h * max_preview_w / w)
    else
        ch = max_preview_h
        cw = math.floor(w * max_preview_h / h)
    end
    local x, y = gfx.mouse_x - cw/2, gfx.mouse_y - ch/2

    -- Preview background: match grade color of dragged item
    local preview_color = theme.colors.btn_active
    if config.state.drag.source_degree ~= -1 then
        preview_color = colors.DegreeColor(config.state.drag.source_degree)
    elseif config.state.drag.source_slot_idx ~= -1 then
        local src_slot = config.state.progression[config.state.drag.source_slot_idx]
        if src_slot then
            preview_color = colors.DegreeColor(src_slot.degree)
        end
    end
    helpers.SetColor(preview_color, 0.8)
    components.DrawRoundedRect(x, y, cw, ch, 8, true)

    helpers.SetColor(theme.colors.text)

    if config.state.drag.source_degree ~= -1 then
        -- Dragging from a pad: show actual note name + roman numeral
        local degree = config.state.drag.source_degree
        local label = format.ChordLabel({root_index=config.state.root_index, scale_index=config.state.scale_index, degree=degree, octave=config.state.octave, chord_mode_index=config.state.chord_mode_index})
        local roman = format.RomanNumeral(degree)

        local main_font = math.max(math.floor(ch * 0.35), 8)
        local sub_font = math.max(math.floor(ch * 0.25), 7)

        gfx.setfont(1, "Calibri", main_font)
        local lw, lh = gfx.measurestr(label)
        gfx.x, gfx.y = x + (cw - lw) / 2, y + (ch / 2) - lh - 2
        gfx.drawstr(label)

        gfx.setfont(1, "Calibri", sub_font)
        local rw = gfx.measurestr(roman)
        gfx.x, gfx.y = x + (cw - rw) / 2, y + (ch / 2) + 4
        gfx.drawstr(roman)

    elseif config.state.drag.source_slot_idx ~= -1 then
        -- Dragging from a slot: show actual slot content
        local slot = config.state.progression[config.state.drag.source_slot_idx]
        if slot then
            local label = format.ChordLabel({root_index=slot.root_index, scale_index=slot.scale_index, degree=slot.degree, octave=slot.octave, chord_mode_index=slot.chord_mode_index})
            local roman = format.RomanNumeral(slot.degree)

            local main_font = math.max(math.floor(ch * 0.35), 8)
            local sub_font = math.max(math.floor(ch * 0.25), 7)

            gfx.setfont(1, "Calibri", main_font)
            local lw, lh = gfx.measurestr(label)
            gfx.x, gfx.y = x + (cw - lw) / 2, y + (ch / 2) - lh - 2
            gfx.drawstr(label)

            gfx.setfont(1, "Calibri", sub_font)
            local rw = gfx.measurestr(roman)
            gfx.x, gfx.y = x + (cw - rw) / 2, y + (ch / 2) + 4
            gfx.drawstr(roman)
        else
            local main_font = math.max(math.floor(ch * 0.35), 8)
            gfx.setfont(1, "Calibri", main_font)
            local label = "↕ REORDER"
            local lw, lh = gfx.measurestr(label)
            gfx.x, gfx.y = x + (cw - lw) / 2, y + (ch - lh) / 2
            gfx.drawstr(label)
        end
    end

end

-- Barrel re-exports (extracted modules)
components.DrawButton = buttons.DrawButton
components.DrawToolIcon = buttons.DrawToolIcon
components.DrawTransportButton = buttons.DrawTransportButton
components.DrawNoteDisplay = buttons.DrawNoteDisplay
components.DrawPaginator = paginator.DrawPaginator
components.DrawDropdown = dropdown.DrawDropdown

return components
