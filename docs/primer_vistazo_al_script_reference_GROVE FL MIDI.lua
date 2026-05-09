-- @version 1.2.6
-- @author Antigravity (Final Edition)
-- @about
--   Permite tocar escalas musicales usando el teclado del PC con una interfaz moderna.
--   Incluye Vista Compacta integrada en barra de transporte y feedback visual pulsante.

local script_title = "Scale Runner"

-- =========================================================
-- DATOS MUSICALES
-- =========================================================

local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

local SCALES = {
    {name = "Mayor (Jónica)", intervals = {0, 2, 4, 5, 7, 9, 11}}, 
    {name = "Menor Natural (Eólica)", intervals = {0, 2, 3, 5, 7, 8, 10}},
    {name = "Menor Armónica", intervals = {0, 2, 3, 5, 7, 8, 11}},
    {name = "Dórica", intervals = {0, 2, 3, 5, 7, 9, 10}},
    {name = "Frigia", intervals = {0, 1, 3, 5, 7, 8, 10}},
    {name = "Lidia", intervals = {0, 2, 4, 6, 7, 9, 11}},
    {name = "Mixolidia", intervals = {0, 2, 4, 5, 7, 9, 10}},
    {name = "Locria", intervals = {0, 1, 3, 5, 6, 8, 10}},
    {name = "Pentatónica Mayor", intervals = {0, 2, 4, 7, 9}},
    {name = "Pentatónica Menor", intervals = {0, 3, 5, 7, 10}},
    {name = "Blues", intervals = {0, 3, 5, 6, 7, 10}},
    {name = "Cromática (Todas)", intervals = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}}
}

local KEY_MAP = {
    [122] = 1, [120] = 2, [99]  = 3, [118] = 4, [98]  = 5, [110] = 6, [109] = 7, [44]  = 8, [46]  = 9,
    [97]  = 8, [115] = 9, [100] = 10, [102] = 11, [103] = 12, [104] = 13, [106] = 14, [107] = 15, [108] = 16,
    [113] = 15, [119] = 16, [101] = 17, [114] = 18, [116] = 19, [121] = 20, [117] = 21, [105] = 22, [111] = 23, [112] = 24
}

local VELOCITY_MAP = {
    -- Row Z (Lowe/Subtle)
    [122]=85, [120]=85, [99]=85, [118]=85, [98]=85, [110]=85, [109]=85, [44]=85, [46]=85,
    -- Row A (Regular)
    [97]=100, [115]=100, [100]=100, [102]=100, [103]=100, [104]=100, [106]=100, [107]=100, [108]=100,
    -- Row Q (Accent/Strong)
    [113]=118, [119]=118, [101]=118, [114]=118, [116]=118, [121]=118, [117]=118, [105]=118, [111]=118, [112]=118
}

-- Virtual Key Codes for JS_API (Background Input)
-- Z=0x5A, X=0x58, C=0x43, V=0x56, B=0x42, N=0x4E, M=0x4D, ,=0xBC, .=0xBE
-- A=0x41, S=0x53, D=0x44, F=0x46, G=0x47, H=0x48, J=0x4A, K=0x4B, L=0x4C
-- Q=0x51, W=0x57, E=0x45, R=0x52, T=0x54, Y=0x59, U=0x55, I=0x49, O=0x4F, P=0x50
local VKEY_MAP = {
    -- Row Z
    [0x5A] = 1, [0x58] = 2, [0x43] = 3, [0x56] = 4, [0x42] = 5, [0x4E] = 6, [0x4D] = 7, [0xBC] = 8, [0xBE] = 9,
    -- Row A
    [0x41] = 8, [0x53] = 9, [0x44] = 10, [0x46] = 11, [0x47] = 12, [0x48] = 13, [0x4A] = 14, [0x4B] = 15, [0x4C] = 16,
    -- Row Q
    [0x51] = 15, [0x57] = 16, [0x45] = 17, [0x52] = 18, [0x54] = 19, [0x59] = 20, [0x55] = 21, [0x49] = 22, [0x4F] = 23, [0x50] = 24
}

-- Map VKey to Velocity (reuse logic)
local VKEY_VELOCITY_MAP = {
    [0x5A]=85, [0x58]=85, [0x43]=85, [0x56]=85, [0x42]=85, [0x4E]=85, [0x4D]=85, [0xBC]=85, [0xBE]=85,
    [0x41]=100, [0x53]=100, [0x44]=100, [0x46]=100, [0x47]=100, [0x48]=100, [0x4A]=100, [0x4B]=100, [0x4C]=100,
    [0x51]=118, [0x57]=118, [0x45]=118, [0x52]=118, [0x54]=118, [0x59]=118, [0x55]=118, [0x49]=118, [0x4F]=118, [0x50]=118
}

local CHORD_MODES = {
    {name="Off", offsets={0}},
    {name="Triada", offsets={0, 2, 4}},
    {name="7ma", offsets={0, 2, 4, 6}},
    {name="9na", offsets={0, 2, 4, 6, 8}}
}

local VIEW_MODES = { FULL = 1, COMPACT = 2 }

local state = {
    view_mode = VIEW_MODES.FULL,
    root_index = 1, scale_index = 1, octave = 4, chord_mode_index = 1, 
    use_velocity = true,
    last_note_played = "None", active_note_draw_timer = 0,
    key_states = {},
    mouse_pad_state = { active_degree = -1, midi_notes = {} },
    drag = { is_dragging = false, source_degree = -1, x = 0, y = 0 },
    progression = {},
    sequencer = { is_playing = false, current_step = 0, last_measure = -1, midi_notes = {} },
    last_mouse_cap = 0, mouse_click = false 
}

for i=1, 8 do state.progression[i] = nil end
for k_code, _ in pairs(VKEY_MAP) do state.key_states[k_code] = {is_pressed = false, midi_notes = {}} end

-- =========================================================
-- THEME & MODERN UI
-- =========================================================

local THEME = {
    bg = {0.12, 0.12, 0.14, 1},        -- Darker, slightly blue-ish grey
    text = {0.92, 0.92, 0.95, 1},      -- White-ish
    text_dim = {0.5, 0.55, 0.6, 1},    -- Cool grey
    btn_bg = {0.18, 0.18, 0.22, 1},    -- Dark slate
    btn_hover = {0.25, 0.25, 0.30, 1}, -- Lighter slate
    btn_active = {0.0, 0.75, 0.8, 1},  -- Cyan/Teal (Electric)
    pad_bg = {0.15, 0.15, 0.18, 1},
    pad_active = {0.0, 0.85, 0.9, 1},  -- Brighter Cyan
    slot_empty = {0.1, 0.1, 0.12, 1},
    slot_filled = {0.2, 0.4, 0.5, 1},
    slot_playing = {0.0, 0.9, 0.5, 1}, -- Green for playhead
    accent_glow = {0.0, 0.8, 0.85, 0.4} -- Glow color
}

local function SetColor(c, alpha_mult) 
    gfx.set(c[1], c[2], c[3], (c[4] or 1) * (alpha_mult or 1)) 
end

local function DrawRoundedRect(x, y, w, h, r, fill, border_color)
    if r > w/2 then r = w/2 end
    if r > h/2 then r = h/2 end
    
    if fill then
        gfx.rect(x+r, y, w-2*r, h, 1)
        gfx.rect(x, y+r, w, h-2*r, 1)
        gfx.circle(x+r, y+r, r, 1, 1)
        gfx.circle(x+w-r-1, y+r, r, 1, 1)
        gfx.circle(x+r, y+h-r-1, r, 1, 1)
        gfx.circle(x+w-r-1, y+h-r-1, r, 1, 1)
    end
    
    if border_color then
        SetColor(border_color)
        gfx.roundrect(x, y, w, h, r, 1)
    end
end

-- =========================================================
-- LOGICA MUSICAL
-- =========================================================

local function GetMidiNote(root_idx, scale_idx, degree_idx, octave_val)
    local root = root_idx - 1
    local scale = SCALES[scale_idx]
    local n_scale = #scale.intervals
    local deg0 = degree_idx - 1
    local oct_off = math.floor(deg0 / n_scale)
    local interval = scale.intervals[(deg0 % n_scale) + 1]
    return (octave_val + 1) * 12 + root + (oct_off * 12) + interval
end

local function SendMidi(note, on, velocity)
    if not note or note < 0 or note > 127 then return end -- Final MIDI Range Safety
    local vel = velocity or 100
    reaper.StuffMIDIMessage(0, on and 0x90 or 0x80, note, on and vel or 0)
    if on then
        local name = NOTE_NAMES[(note % 12) + 1] or "?"
        state.last_note_played = string.format("%s%d", name, math.floor(note/12)-1)
        state.active_note_draw_timer = 20
    end
end

local function TriggerChord(degree, on, ctx, velocity)
    local c = ctx or state
    local notes = {}
    local offsets = CHORD_MODES[c.chord_mode_index].offsets
    for _, off in ipairs(offsets) do
        local n = GetMidiNote(c.root_index, c.scale_index, degree + off, c.octave)
        SendMidi(n, on, velocity)
        table.insert(notes, n)
    end
    return notes
end

local function GetLastFilledSlot()
    for i=8, 1, -1 do if state.progression[i] then return i end end
    return 8
end

local function StopSequencer()
    state.sequencer.is_playing = false
    -- Kill sequencer notes
    for _, n in ipairs(state.sequencer.midi_notes) do SendMidi(n, false) end
    state.sequencer.midi_notes = {}
    state.sequencer.last_measure = -1
    state.sequencer.current_step = 0
end

local function ResetVisualStates()
    state.mouse_pad_state.active_degree = -1
    state.mouse_pad_state.midi_notes = {}
    for k, s in pairs(state.key_states) do
        s.is_pressed = false
        s.midi_notes = {}
    end
end

local function AllNotesOff()
    reaper.StuffMIDIMessage(0, 0xB0, 123, 0) -- MIDI All Notes Off
    StopSequencer()
    ResetVisualStates()
    -- Ensure all PC keyboard notes are also cleared
    for k, _ in pairs(state.key_states) do
        state.key_states[k].is_pressed = false
        state.key_states[k].midi_notes = {}
    end
end

local function RunSequencer()
    if not state.sequencer.is_playing then return end
    if (reaper.GetPlayState() & 1) == 0 then
        if #state.sequencer.midi_notes > 0 then StopSequencer() state.sequencer.is_playing = true end
        return
    end
    local _, measures = reaper.TimeMap2_timeToBeats(0, reaper.GetPlayPosition2())
    local cur_m = math.floor(measures)
    if cur_m ~= state.sequencer.last_measure then
        -- Clear previous notes first
        for _, n in ipairs(state.sequencer.midi_notes) do SendMidi(n, false) end
        state.sequencer.midi_notes = {} -- Reset buffer immediately
        
        local loop = GetLastFilledSlot()
        state.sequencer.current_step = (cur_m % loop) + 1
        state.sequencer.last_measure = cur_m
        local slot = state.progression[state.sequencer.current_step]
        if slot then 
            state.sequencer.midi_notes = TriggerChord(slot.degree, true, slot) 
        end
    end
end

local function ExportToMidi()
    local track = reaper.GetSelectedTrack(0,0) or (reaper.InsertTrackAtIndex(0,true) or reaper.GetTrack(0,0))
    local start_qn = reaper.TimeMap_timeToQN(reaper.GetCursorPosition())
    local count = GetLastFilledSlot()
    local end_qn = start_qn + (count * 4)
    local item = reaper.CreateNewMIDIItemInProj(track, reaper.TimeMap_QNToTime(start_qn), reaper.TimeMap_QNToTime(end_qn), false)
    local take = reaper.GetActiveTake(item)
    for i=1, count do
        local slot = state.progression[i]
        if slot then
            local q0 = start_qn + (i-1)*4
            local p0, p1 = reaper.MIDI_GetPPQPosFromProjQN(take, q0), reaper.MIDI_GetPPQPosFromProjQN(take, q0+4)
            for _, off in ipairs(CHORD_MODES[slot.chord_mode_index].offsets) do
                local n = GetMidiNote(slot.root_index, slot.scale_index, slot.degree+off, slot.octave)
                reaper.MIDI_InsertNote(take, false, false, p0, p1, 0, n, 96, true)
            end
        end
    end
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
end

-- =========================================================
-- GUI COMPONENTS
-- =========================================================

local function DrawButton(x, y, w, h, label, active)
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    
    -- Background
    local c = active and THEME.btn_active or (hover and THEME.btn_hover or THEME.btn_bg)
    SetColor(c)
    DrawRoundedRect(x, y, w, h, 4, true)
    
    -- Glow effect if active
    if active then
        gfx.set(c[1], c[2], c[3], 0.3)
        DrawRoundedRect(x-2, y-2, w+4, h+4, 6, true)
    end
    
    -- Text
    SetColor(active and {0.1,0.1,0.1,1} or THEME.text) -- Dark text on active btn
    local sw, sh = gfx.measurestr(label)
    gfx.x, gfx.y = x+(w-sw)/2, y+(h-sh)/2
    gfx.drawstr(label)
    
    return not state.drag.is_dragging and state.mouse_click and hover
end
local function DrawScalePad(x, y, w, h, deg)
    local note_n = NOTE_NAMES[(GetMidiNote(state.root_index, state.scale_index, deg, state.octave) % 12) + 1]
    
    -- Check Key State specifically for Visual Decay
    local k_code = 0
    local is_pressed = false
    -- Iterate VKEY_MAP to find which key corresponds to this degree
    for vk, d in pairs(VKEY_MAP) do 
        if d == deg then 
            k_code = vk
            if state.key_states[vk] and state.key_states[vk].is_pressed then is_pressed = true end
            -- Don't break immediately, in case multiple keys map to same degree? 
            -- Actually unique mapping usually.
            if is_pressed then break end 
        end 
    end
    
    -- Decay Logic
    if k_code > 0 then
        -- Initialize pulse if needed (for keys not yet pressed this session)
        if not state.key_states[k_code] then state.key_states[k_code] = {is_pressed=false, midi_notes={}} end
        if not state.key_states[k_code].pulse then state.key_states[k_code].pulse = 0 end
        
        if is_pressed then
            state.key_states[k_code].pulse = 1.0 -- Full brightness
        elseif state.key_states[k_code].pulse > 0 then
            state.key_states[k_code].pulse = state.key_states[k_code].pulse - 0.1 -- Decay
            if state.key_states[k_code].pulse < 0 then state.key_states[k_code].pulse = 0 end
        end
    end
    
    local act = (state.mouse_pad_state.active_degree == deg) or is_pressed
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    
    local pulse_val = (k_code > 0 and state.key_states[k_code].pulse) or 0
    if act then pulse_val = 1.0 end
    
    -- Background
    if pulse_val > 0.01 then
        -- Interpolate Color
        local c1 = THEME.pad_bg
        local c2 = THEME.pad_active
        local r = c1[1] + (c2[1]-c1[1])*pulse_val
        local g = c1[2] + (c2[2]-c1[2])*pulse_val
        local b = c1[3] + (c2[3]-c1[3])*pulse_val
        gfx.set(r, g, b, 1)
        
        -- Glow
        DrawRoundedRect(x-(3*pulse_val), y-(3*pulse_val), w+(6*pulse_val), h+(6*pulse_val), 8, true)
        
    else
        SetColor(hover and THEME.btn_hover or THEME.pad_bg)
    end
    
    -- Fill
    DrawRoundedRect(x, y, w, h, 6, true)
    
    -- Text
    SetColor((pulse_val > 0.5) and {0,0,0.1,1} or THEME.text)
    local nw, nh = gfx.measurestr(note_n)
    gfx.x, gfx.y = x+(w-nw)/2, y+10; gfx.drawstr(note_n)
    
    gfx.setfont(1, "Calibri", 11)
    local dw, dh = gfx.measurestr(tostring(deg))
    gfx.x, gfx.y = x+(w-dw)/2, y+35; gfx.drawstr(tostring(deg))
    gfx.setfont(1, "Calibri", 16)
    
    if hover and (gfx.mouse_cap&1)==1 and not state.drag.is_dragging and state.mouse_pad_state.active_degree==-1 then
        state.drag.is_dragging, state.drag.source_degree = true, deg
        state.mouse_pad_state.active_degree = deg
        state.mouse_pad_state.midi_notes = TriggerChord(deg, true)
    end
    if state.mouse_pad_state.active_degree == deg and (gfx.mouse_cap&1)==0 then
        for _, n in ipairs(state.mouse_pad_state.midi_notes) do SendMidi(n, false) end
        state.mouse_pad_state.active_degree, state.mouse_pad_state.midi_notes = -1, {}
        if state.drag.is_dragging and state.drag.source_degree == deg then
            state.drag.is_dragging, state.drag.source_degree = false, -1
            return true
        end
    end
    return false
end

local function SaveProgression()
    local str = ""
    for i = 1, 8 do
        local slot = state.progression[i]
        if slot then
            str = str .. string.format("%d,%d,%d,%d,%d;", 
                slot.degree, slot.root_index, slot.scale_index, slot.octave, slot.chord_mode_index)
        else
            str = str .. "nil;"
        end
    end
    reaper.SetExtState(script_title, "progression", str, true)
    reaper.SetExtState(script_title, "config", string.format("%d,%d,%d,%d,%d,%d", 
        state.root_index, state.scale_index, state.octave, state.chord_mode_index, state.use_velocity and 1 or 0, state.view_mode), true)
end

local function LoadProgression()
    local str = reaper.GetExtState(script_title, "progression")
    if str ~= "" then
        local i = 1
        for part in string.gmatch(str, "([^;]+)") do
            if part ~= "nil" then
                local d, r, s, o, c = string.match(part, "(%d+),(%d+),(%d+),(%d+),(%d+)")
                if d then
                    state.progression[i] = {
                        degree = tonumber(d), root_index = tonumber(r),
                        scale_index = tonumber(s), octave = tonumber(o),
                        chord_mode_index = tonumber(c)
                    }
                end
            end
            i = i + 1
        end
    end
    local cfg = reaper.GetExtState(script_title, "config")
    if cfg ~= "" then
        local r, s, o, c, v, vm, ox, oy = string.match(cfg, "([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]*)")

        if r then
            -- Defensive clamping to prevent crashes from corrupted or old data
            state.root_index = math.max(1, math.min(#NOTE_NAMES, tonumber(r) or 1))
            state.scale_index = math.max(1, math.min(#SCALES, tonumber(s) or 1))
            state.octave = math.max(1, math.min(7, tonumber(o) or 4))
            state.chord_mode_index = math.max(1, math.min(#CHORD_MODES, tonumber(c) or 1))
            if v and v ~= "" then
                state.use_velocity = (tonumber(v) == 1)
            else
                state.use_velocity = true
            end
            if vm and vm ~= "" then
                state.view_mode = tonumber(vm) or VIEW_MODES.FULL
            end
            if ox and ox ~= "" then state.view_offset_x = tonumber(ox) or 100 end
            if oy and oy ~= "" then state.view_offset_y = tonumber(oy) or 0 end
        end
    end
end



local function DrawProgressionSlot(idx, x, y, w, h, dropped)
    local slot = state.progression[idx]
    local play = state.sequencer.is_playing and state.sequencer.current_step == idx
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    
    -- Glow effect for active playback
    if play then
        gfx.set(0, 1, 0.5, 0.2)
        DrawRoundedRect(x-4, y-4, w+8, h+8, 10, true)
    elseif hover then
        gfx.set(1, 1, 1, 0.05)
        DrawRoundedRect(x-2, y-2, w+4, h+4, 6, true)
    end
    
    SetColor(play and THEME.slot_playing or (dropped and hover and THEME.btn_active or (slot and (hover and THEME.btn_hover or THEME.slot_filled) or (hover and THEME.btn_bg or THEME.slot_empty))))
    DrawRoundedRect(x, y, w, h, 6, true)
    
    if slot then
        local nn = NOTE_NAMES[(GetMidiNote(slot.root_index, slot.scale_index, slot.degree, slot.octave) % 12) + 1]
        SetColor(play and {0,0,0,1} or THEME.text)
        local nw = gfx.measurestr(nn); gfx.x, gfx.y = x+(w-nw)/2, y+8; gfx.drawstr(nn)
        
        gfx.setfont(1, "Calibri", 11)
        local cn = CHORD_MODES[slot.chord_mode_index].name:sub(1,3)
        local cw = gfx.measurestr(cn); gfx.x, gfx.y = x+(w-cw)/2, y+28; gfx.drawstr(cn)
        gfx.setfont(1, "Calibri", 16)
        
        -- Logic
        if not state.drag.is_dragging and (gfx.mouse_cap&1)==1 and hover then
            if state.mouse_pad_state.active_degree ~= 100+idx then
                if state.mouse_pad_state.active_degree ~= -1 then for _, n in ipairs(state.mouse_pad_state.midi_notes) do SendMidi(n, false) end end
                state.mouse_pad_state.active_degree = 100+idx
                state.mouse_pad_state.midi_notes = TriggerChord(slot.degree, true, slot)
            end
        elseif state.mouse_pad_state.active_degree == 100+idx and (gfx.mouse_cap&1)==0 then
            for _, n in ipairs(state.mouse_pad_state.midi_notes) do SendMidi(n, false) end
            state.mouse_pad_state.active_degree, state.mouse_pad_state.midi_notes = -1, {}
        end
        if (gfx.mouse_cap&2)==2 and hover then 
            state.progression[idx] = nil 
            SaveProgression()
        end
    end
    if dropped and hover then
        state.progression[idx] = { degree=dropped, root_index=state.root_index, scale_index=state.scale_index, octave=state.octave, chord_mode_index=state.chord_mode_index }
        SaveProgression()
    end
end

local function SaveProgression()
    reaper.SetExtState(script_title, "config", string.format("%d,%d,%d,%d,%d,%d,%d,%d", 
        state.root_index, state.scale_index, state.octave, state.chord_mode_index, state.use_velocity and 1 or 0, state.view_mode, state.view_offset_x or 100, state.view_offset_y or 0), true)
    local prog_str = ""
    for i=1, 8 do
        local slot = state.progression[i]
        if slot then
            prog_str = prog_str .. string.format("%d,%d,%d,%d,%d;", slot.degree, slot.root_index, slot.scale_index, slot.octave, slot.chord_mode_index)
        else
            prog_str = prog_str .. "0;" -- 0 indicates empty slot
        end
    end
    reaper.SetExtState(script_title, "progression", prog_str, true)
end

-- =========================================================
-- DEPENDENCIES CHECK
-- =========================================================

if not reaper.JS_Composite then
    reaper.MB("Please install 'js_ReaScriptAPI' via ReaPack to use the Compact View features.", script_title, 0)
    return
end

-- =========================================================
-- LICE / COMPOSITE HELPERS (For Compact View)
-- =========================================================

local lice_font = nil
local bitmap = nil
local transport_hwnd = nil
local intercept_active = false

local gdi_font = nil

local function EnsureLICE()
    if not bitmap then
        bitmap = reaper.JS_LICE_CreateBitmap(true, 1, 1) -- Size will be updated
    end
    if not lice_font then
        lice_font = reaper.JS_LICE_CreateFont()
        -- JS_GDI_CreateFont(height, weight, angle, orientation, underline, italic, fontname) (guess based on 7 max)
        -- Or simply: JS_GDI_CreateFont(height, weight, 0, 0, 0, 0, "Calibri")
        gdi_font = reaper.JS_GDI_CreateFont(13, 400, 0, 0, 0, 0, "Calibri")
        reaper.JS_LICE_SetFontFromGDI(lice_font, gdi_font, "")
    end
end

local function DrawLICERect(bm, x, y, w, h, color, fill)
    local a = 1
    local c = reaper.ColorToNative(math.floor(color[1]*255), math.floor(color[2]*255), math.floor(color[3]*255)) | 0xFF000000 
    if fill then
        reaper.JS_LICE_FillRect(bm, x, y, w, h, c, a, 0)
    else
        reaper.JS_LICE_RoundRect(bm, x, y, w, h, 0, c, a, 0, true)
    end
end

local function DrawLICEText(bm, x, y, text, color)
    local c = reaper.ColorToNative(math.floor(color[1]*255), math.floor(color[2]*255), math.floor(color[3]*255)) | 0xFF000000
    reaper.JS_LICE_SetFontColor(lice_font, c)
    local len = string.len(text)
    reaper.JS_LICE_DrawText(bm, lice_font, text, len, x, y, 1000, 100) -- Rect limits loose
end

-- local function MeasureLICEText(text)
--     return reaper.JS_LICE_MeasureText(lice_font, text) -- API issues, using fixed width for now
-- end

-- =========================================================
-- COMPACT VIEW (EMBEDDED) LOGIC
-- =========================================================

-- Defaults
if not state.view_offset_x then state.view_offset_x = 100 end
if not state.view_offset_y then state.view_offset_y = 0 end

local cv_w, cv_h = 0, 26 -- Position relative to Transport
local cv_areas = {} -- Store clickable zones {x,y,w,h, callback}

local function UpdateCompactView()
    EnsureLICE()
    
    -- Calculate content width
    local key_name = NOTE_NAMES[state.root_index]
    local scale_name = SCALES[state.scale_index].name
    local short_scale = scale_name:sub(1, 10) .. (#scale_name > 10 and ".." or "")
    local oct_name = "C" .. state.octave
    local chord_name = CHORD_MODES[state.chord_mode_index].name:sub(1,3)
    
    -- Positioning Logic
    cv_x = state.view_offset_x
    cv_y = 2 -- Default fallback
    
    if transport_hwnd then
        local _, w_trans, h_trans = reaper.JS_Window_GetClientSize(transport_hwnd)
        -- Vertical Center
        cv_y = math.floor((h_trans - cv_h) / 2) + state.view_offset_y
    end
    
    -- Margins and Spacing
    local pad = 8
    local x = 5
    local total_w = 0
    
    -- Fixed Widths (Manual estimation for Calibri 13)
    local w_key = 25
    local w_scale = 85
    local w_oct = 25
    local w_chord = 35
    local w_switch = 20
    
    cv_w = x + w_key + w_scale + w_oct + w_chord + w_switch + 5
    
    -- Resize Bitmap
    reaper.JS_LICE_Resize(bitmap, cv_w, cv_h)
    
    -- Clear (Draw Background)
    DrawLICERect(bitmap, 0, 0, cv_w, cv_h, THEME.bg, true)
    
    cv_areas = {} -- Reset click areas for this frame
    
    local function AddArea(elem_x, elem_w, callback)
        table.insert(cv_areas, {x=elem_x, y=0, w=elem_w, h=cv_h, cb=callback})
    end
    
    -- Draw Elements
    
    -- Key
    DrawLICEText(bitmap, x, 6, key_name, THEME.text)
    AddArea(x, w_key, "key")
    x = x + w_key 
    
    -- Scale (Or Flash Note)
    local note_display = short_scale
    local note_color = THEME.text
    
    -- Visual Feedback specific for Compact View
    if state.active_note_draw_timer and state.active_note_draw_timer > 0 then
        -- Temporarily show Note instead of Scale Name
        local n_curr = state.last_note_played or ""
        if n_curr ~= "None" then
            note_display = "-> " .. n_curr
            note_color = THEME.pad_active -- Flash Color
            -- Flash background slightly?
            DrawLICERect(bitmap, x, 2, w_scale, cv_h-4, THEME.btn_hover, true)
        end
    end

    DrawLICEText(bitmap, x, 6, note_display, note_color)
    AddArea(x, w_scale, "scale")
    x = x + w_scale 
    
    -- Octave
    DrawLICEText(bitmap, x, 6, oct_name, THEME.text_dim)
    AddArea(x, w_oct, "octave")
    x = x + w_oct 
    
    -- Chord
    DrawLICEText(bitmap, x, 6, chord_name, THEME.text_dim)
    AddArea(x, w_chord, "chord")
    x = x + w_chord
    
    -- Separator
    DrawLICERect(bitmap, x + 2, 4, 1, cv_h-8, THEME.text_dim, true)
    
    -- Switch Button [>]
    x = cv_w - w_switch
    DrawLICEText(bitmap, x+5, 6, ">", THEME.btn_active)
    AddArea(x, w_switch, "switch")
    
    -- Update Composite on Transport
    if transport_hwnd then
        reaper.JS_Composite(transport_hwnd, cv_x, cv_y, cv_w, cv_h, bitmap, 0, 0, cv_w, cv_h, true)
        reaper.JS_Window_InvalidateRect(transport_hwnd, cv_x, cv_y, cv_x+cv_w, cv_y+cv_h, false)
    end
end

-- =========================================================
-- MAIN
-- =========================================================

local function Cleanup()
    if intercept_active and transport_hwnd then
        reaper.JS_WindowMessage_Release(transport_hwnd, "WM_LBUTTONDOWN")
        reaper.JS_WindowMessage_Release(transport_hwnd, "WM_RBUTTONDOWN")
        reaper.JS_Composite_Unlink(transport_hwnd, bitmap)
        intercept_active = false
    end
    if bitmap then
        reaper.JS_LICE_DestroyBitmap(bitmap)
        bitmap = nil
    end
    if lice_font then
        reaper.JS_LICE_DestroyFont(lice_font)
        lice_font = nil
    end
    if gdi_font then
        reaper.JS_GDI_DeleteObject(gdi_font)
        gdi_font = nil
    end
    gfx.quit()
end

-- Window state
local last_gfx_state = {dock=0, x=100, y=100, w=420, h=540}

local function Init()
    -- Try to restore last window state if available
    local dock, x, y, w, h = last_gfx_state.dock, last_gfx_state.x, last_gfx_state.y, last_gfx_state.w, last_gfx_state.h
    
    -- If saved in ExtState, usage:
    -- We are already loading config in LoadProgression, let's just use defaults or saved if we add them to config string.
    -- For now, session persistence (variable) is enough for toggling.
    
    gfx.init(script_title, w, h, dock, x, y)
    gfx.setfont(1, "Calibri", 16)
    
    LoadProgression() -- Load State
    
    if state.view_mode == VIEW_MODES.COMPACT then
        SwitchViewMode() -- This will close GFX and start Compact Mode loop
    end
end

local function SwitchViewMode()
    if state.view_mode == VIEW_MODES.FULL then
        -- Saving GFX state before closing
        last_gfx_state.dock, last_gfx_state.x, last_gfx_state.y, last_gfx_state.w, last_gfx_state.h = gfx.dock(-1, 0, 0, 0, 0)
        
        state.view_mode = VIEW_MODES.COMPACT
        gfx.quit() -- Close GFX window
        -- Start Composite Mode logic happens in MainLoop
    else
        state.view_mode = VIEW_MODES.FULL
        -- Cleanup Composite
        Cleanup() 
        state.view_mode = VIEW_MODES.FULL -- Re-set just in case
        
        -- Re-init GFX with restored state
        local dock, x, y, w, h = last_gfx_state.dock, last_gfx_state.x, last_gfx_state.y, last_gfx_state.w, last_gfx_state.h
        gfx.init(script_title, w, h, dock, x, y)
        gfx.setfont(1, "Calibri", 16)
    end
    SaveProgression()
end

-- Context Menu (Shared Logic mostly, adapted for LICE pos if needed)
local function ShowContextMenu(is_compact)
    local menu = "#Scale Runner Options|"
    menu = menu .. (state.view_mode == VIEW_MODES.COMPACT and "Cambiar a Vista Completa" or "Cambiar a Vista Compacta") .. "|"
    menu = menu .. ">Tonalidad|"
    for i, n in ipairs(NOTE_NAMES) do
        menu = menu .. (state.root_index == i and "!" or "") .. n .. "|"
    end
    menu = menu .. "<|>Escala|"
    for i, s in ipairs(SCALES) do
        menu = menu .. (state.scale_index == i and "!" or "") .. s.name .. "|"
    end
    menu = menu .. "<|>Octava|"
    for i=1, 7 do
        menu = menu .. (state.octave == i and "!" or "") .. "C" .. i .. "|"
    end
    menu = menu .. "<|>Acorde|"
    for i, m in ipairs(CHORD_MODES) do
        menu = menu .. (state.chord_mode_index == i and "!" or "") .. m.name .. "|"
    end
    menu = menu .. "<"
    
    if is_compact then
        menu = menu .. "|>Herramientas|"
        menu = menu .. "Exportar Progresion MIDI|"
        menu = menu .. "Panic (Notas Off)|"
        menu = menu .. "|>Posicion|"
        menu = menu .. "Ajustar Offset X/Y...|"
        menu = menu .. "Reseter Verticalmente|"
        menu = menu .. "<"
        menu = menu .. "<"
    end
    
    if is_compact then
        -- Native Menu for Composite
        gfx.init("", 0, 0) -- Dummy for menu
        local m_x, m_y = reaper.GetMousePosition()
        gfx.x, gfx.y = gfx.screentoclient(m_x, m_y)
    else
        gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
    end

    local ret = gfx.showmenu(menu)
    
    if is_compact then gfx.quit() end -- Kill dummy
    
    -- Calculate generic menu offsets
    local OFFSET_TONE = 2
    local OFFSET_SCALE = OFFSET_TONE + #NOTE_NAMES
    local OFFSET_OCT = OFFSET_SCALE + #SCALES
    local OFFSET_CHORD = OFFSET_OCT + 7
    local OFFSET_POS = OFFSET_CHORD + #CHORD_MODES
    
    local OFFSET_TOOLS = OFFSET_POS
    local OFFSET_POS_NEW = OFFSET_TOOLS + 2 -- Export + Panic
    
    if ret == 1 then
        SwitchViewMode()
    elseif ret >= OFFSET_TONE and ret < OFFSET_SCALE then
        state.root_index = ret - OFFSET_TONE + 1
    elseif ret >= OFFSET_SCALE and ret < OFFSET_OCT then
        state.scale_index = ret - OFFSET_SCALE + 1
    elseif ret >= OFFSET_OCT and ret < OFFSET_CHORD then
        state.octave = ret - OFFSET_OCT + 1
    elseif ret >= OFFSET_CHORD and ret < OFFSET_TOOLS then
        state.chord_mode_index = ret - OFFSET_CHORD + 1
    
    -- Tools (Compact Only)
    elseif is_compact and ret == OFFSET_TOOLS + 1 then ExportToMidi()
    elseif is_compact and ret == OFFSET_TOOLS + 2 then AllNotesOff()
    
    -- Position
    elseif is_compact and ret == OFFSET_POS_NEW + 1 then -- Adjust Offset
         local retval, retvals_csv = reaper.GetUserInputs("Ajustar Posicion", 2, "Offset X,Offset Y", state.view_offset_x .. "," .. state.view_offset_y)
         if retval then
             local nx, ny = retvals_csv:match("([^,]+),([^,]+)")
             if nx then state.view_offset_x = tonumber(nx) end
             if ny then state.view_offset_y = tonumber(ny) end
             SaveProgression()
         end
    elseif is_compact and ret == OFFSET_POS_NEW + 2 then -- Reset Vertical
         state.view_offset_y = 0
         SaveProgression()
    end
    
    if ret > 0 then SaveProgression() end
end

local function HandleCompactClick(x, y)
    -- Check areas
    for _, area in ipairs(cv_areas) do
        if x >= area.x and x <= area.x + area.w then
            if area.cb == "switch" then
                SwitchViewMode()
            else
                ShowContextMenu(true)
            end
            return
        end
    end
    -- Fallback for background click
    ShowContextMenu(true)
end

local function DrawFullView()
    local sx = 15
    SetColor(THEME.btn_active); gfx.x, gfx.y = sx, 45; gfx.drawstr("Tonalidad & Escala")
    for i, n in ipairs(NOTE_NAMES) do if DrawButton(sx+(i-1)*33, 65, 30, 25, n, i==state.root_index) then state.root_index = i SaveProgression() end end
    for i, s in ipairs(SCALES) do
        local col, row = (i-1)%2, math.floor((i-1)/2)
        if DrawButton(sx+col*195, 100+row*22, 185, 18, s.name, i==state.scale_index) then state.scale_index=i SaveProgression() end
    end
    
    SetColor(THEME.btn_active); gfx.x, gfx.y = sx, 235; gfx.drawstr("Octava & Acorde")
    
    -- Velocity Toggle
    if DrawButton(sx + 145, 232, 45, 18, "VEL", state.use_velocity) then
        state.use_velocity = not state.use_velocity
        SaveProgression()
    end
    for i=1,7 do if DrawButton(sx+(i-1)*35, 255, 32, 20, "C"..i, state.octave==i) then state.octave=i SaveProgression() end end
    for i, m in ipairs(CHORD_MODES) do if DrawButton(sx+245+(i-1)*38, 255, 36, 20, m.name:sub(1,3), i==state.chord_mode_index) then state.chord_mode_index=i SaveProgression() end end
    
    SetColor(THEME.btn_active); gfx.x, gfx.y = sx, 290; gfx.drawstr("Performance Pads")
    local pads = #SCALES[state.scale_index].intervals
    local pw = math.min(50, math.floor((gfx.w-40)/pads)-5)
    local drp = nil
    for i=1, pads do if DrawScalePad(sx+(i-1)*(pw+5), 310, pw, 60, i) then drp = i end end
    
    SetColor(THEME.btn_active); gfx.x, gfx.y = sx, 390; gfx.drawstr("Progression Loop")
    
    -- Clear All Button
    if DrawButton(sx + 140, 387, 85, 22, "Limpiar", false) then
        StopSequencer() -- Safety: Stop current sound before clearing
        for i=1, 8 do state.progression[i] = nil end
        SaveProgression()
    end

    if DrawButton(sx+240, 387, 50, 22, state.sequencer.is_playing and "STOP" or "PLAY", state.sequencer.is_playing) then
        state.sequencer.is_playing = not state.sequencer.is_playing
        if not state.sequencer.is_playing then StopSequencer() else state.sequencer.last_measure=-1 end
    end
    
    -- Export Button (Replaces Drag generic)
    if DrawButton(sx+300, 387, 85, 22, "EXPORT", false) then 
        ExportToMidi()
    end
    for i=1,8 do DrawProgressionSlot(i, sx+(i-1)*49, 415, 45, 60, drp) end
    
    -- Bottom Feedback
    local feedback_y = 495
    SetColor({0.08,0.08,0.1,0.95})
    DrawRoundedRect(5, feedback_y, gfx.w-10, 40, 10, true, {0.2, 0.2, 0.2, 0.5})
    
    -- Dynamic Color for active note pulse
    if state.active_note_draw_timer > 0 then
        local p = state.active_note_draw_timer / 5
        gfx.set(THEME.btn_active[1], THEME.btn_active[2], THEME.btn_active[3], 0.5 + p*0.5)
    else
        SetColor(THEME.text_dim)
    end
    
    gfx.x, gfx.y = 20, feedback_y + 12
    gfx.drawstr("Nota: ")
    SetColor(THEME.text); gfx.drawstr(state.last_note_played)
    
    SetColor(THEME.text_dim); gfx.x = gfx.w-90; gfx.drawstr("[P] PANIC")

    if state.drag.is_dragging then
        SetColor(THEME.pad_active); gfx.circle(gfx.mouse_x, gfx.mouse_y, 10, 1, 1)
        SetColor(THEME.text); gfx.x, gfx.y = gfx.mouse_x+15, gfx.mouse_y-5
        gfx.drawstr(state.drag.source_degree==999 and "Insertar MIDI" or "Grado "..state.drag.source_degree)
    end
    
    -- Switch to compact button
    SetColor(THEME.text_dim)
    if DrawButton(gfx.w - 25, 5, 20, 20, "-", false) then SwitchViewMode() end
end

local function Init()
    LoadProgression()
    
    -- Use specific init based on mode
    if state.view_mode == VIEW_MODES.FULL then
        gfx.init(script_title, 420, 540)
        gfx.setfont(1, "Calibri", 16)
        gfx.clear = reaper.ColorToNative(math.floor(THEME.bg[1]*255), math.floor(THEME.bg[2]*255), math.floor(THEME.bg[3]*255))
    else
        -- Compact mode doesn't need GFX window
        -- Just find transport
        transport_hwnd = reaper.JS_Window_Find("Transport", true)
    end
end

local function MainLoop()
    -- =========================================================
    -- SHARED LOGIC (SEQUENCER & TIMERS) - RUNS IN ALL MODES
    -- =========================================================
    
    RunSequencer()
    
    if state.active_note_draw_timer > 0 then 
        state.active_note_draw_timer = state.active_note_draw_timer - 1 
        -- Trigger redraw if fading
        if state.view_mode == VIEW_MODES.COMPACT then UpdateCompactView() end
    end

    -- =========================================================
    -- INPUT HANDLING (GLOBAL KEYBOARD VIA JS_API)
    -- =========================================================
    
    -- Check for Focus (Optional: Only if Reaper is focused? JS_VKeys works globally usually)
    -- But to avoid playing while typing in other apps, checking Reaper focus is good practice.
    -- However, JS_VKeys_GetState usually respects if Reaper is main window. 
    -- Let's just poll.
    
    for vk, deg in pairs(VKEY_MAP) do
        local state_byte = reaper.JS_VKeys_GetState(0):byte(vk)
        local dn = (state_byte & 1) == 1
        
        -- Mapping VKEY to our internal state key (we can reuse the ASCII code or just use VK as index)
        -- To keep compatibility with visual decay on old KEY_MAP, we might want to map VK back to ASCII
        -- OR just migrate state.key_states to use VK codes?
        -- Simplest: Migrate state.key_states to use VK codes as keys.
        
        -- Init if missing (legacy safety)
        if not state.key_states[vk] then state.key_states[vk] = {is_pressed=false, midi_notes={}} end
        
        if dn and not state.key_states[vk].is_pressed then
            local vel = state.use_velocity and (VKEY_VELOCITY_MAP[vk] or 100) or 100
            state.key_states[vk].is_pressed, state.key_states[vk].midi_notes = true, TriggerChord(deg, true, nil, vel)
        elseif not dn and state.key_states[vk].is_pressed then
            for _, n in ipairs(state.key_states[vk].midi_notes) do SendMidi(n, false) end
            state.key_states[vk].is_pressed, state.key_states[vk].midi_notes = false, {}
        end
    end
    
    if state.view_mode == VIEW_MODES.FULL then
        local char = gfx.getchar()
        if char == -1 or char == 27 then 
            AllNotesOff() 
            return -- Exit
        end
        
        if char == 32 then reaper.Main_OnCommand(40044, 0) end
        if char == 112 or char == 80 then AllNotesOff() end
        
        local curr_cap = gfx.mouse_cap
        state.mouse_click = (curr_cap&1)==1 and (state.last_mouse_cap&1)==0
        state.last_mouse_cap = curr_cap
    end

    -- =========================================================
    -- VIEW RENDERING
    -- =========================================================

    -- COMPACT MODE LOGIC
    if state.view_mode == VIEW_MODES.COMPACT then
        if not transport_hwnd then 
             transport_hwnd = reaper.JS_Window_Find("Transport", true)
             if not transport_hwnd then
                transport_hwnd = reaper.JS_Window_Find("Transport", false) -- Try loose match
             end
             -- Try localized guess if English fails (long shot but helpful)
             if not transport_hwnd then
                transport_hwnd = reaper.JS_Window_Find("Transporte", false) 
             end
        end
        
        if transport_hwnd then
            -- Intercept Setup
            if not intercept_active then
                reaper.JS_WindowMessage_Intercept(transport_hwnd, "WM_LBUTTONDOWN", false)
                reaper.JS_WindowMessage_Intercept(transport_hwnd, "WM_RBUTTONDOWN", false)
                intercept_active = true
            end
            
            -- Checks for Mouse Clicks on Transport
            local l_peak, _, l_time = reaper.JS_WindowMessage_Peek(transport_hwnd, "WM_LBUTTONDOWN")
            local r_peak, _, r_time = reaper.JS_WindowMessage_Peek(transport_hwnd, "WM_RBUTTONDOWN")
            
            if (l_peak and l_time > 0) or (r_peak and r_time > 0) then
                 local mx, my = reaper.GetMousePosition()
                 local wx, wy = reaper.JS_Window_ScreenToClient(transport_hwnd, mx, my)
                 -- Check collision
                 if wx >= cv_x and wx <= cv_x + cv_w and wy >= cv_y and wy <= cv_y + cv_h then
                     -- Pass Control
                     HandleCompactClick(wx - cv_x, wy - cv_y)
                 end
            end
            
            -- Redraw if needed (e.g. sequencer step changed or simply every frame for smoothness)
            -- Ideally optimize, but for now redraw helps flashing effects
            UpdateCompactView()
        end
        
        -- Keep running loop
        reaper.defer(MainLoop)
        return
    end

    -- FULL MODE LOGIC (GFX)
    SetColor(THEME.bg); gfx.rect(0,0,gfx.w, gfx.h, 1) 
    
    SetColor({0.08, 0.08, 0.1, 1}); gfx.rect(0,0,gfx.w, 35, 1)
    SetColor(THEME.btn_active); gfx.x, gfx.y = 15, 8; gfx.drawstr("SCALE RUNNER"); SetColor(THEME.text_dim); gfx.drawstr("  v1.2.6")
    DrawFullView()
    
    gfx.update(); reaper.defer(MainLoop)
end

reaper.atexit(Cleanup)
Init()
MainLoop()
