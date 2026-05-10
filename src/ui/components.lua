local config = require("config")
local theme = require("ui.theme")
local helpers = require("ui.helpers")
local midi = require("core.midi")

local components = {}

-- Cached scale note tables for DrawPianoKeyboard (Issue 13)
local cached_scale_root = nil
local cached_scale_idx = nil
local cached_scale_notes = {}
local cached_note_to_degree = {}

-- Resolve display color for a degree: grade color or flat blue depending on mode
local function DegreeColor(degree)
    if config.state.color_mode ~= "grade" then
        return theme.colors.btn_active
    end
    return (theme.colors.grade_colors or {})[((degree-1) % 7) + 1] or theme.colors.btn_active
end

-- QWERTY key labels for degrees 1-7 (base octave)
local DEGREE_KEY_LABELS = {"Q", "W", "E", "R", "T", "Y", "U"}
local ROMAN_NUMERALS = {"I", "II", "III", "IV", "V", "VI", "VII"}



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

function components.DrawToolIcon(type, x, y, size, active)
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + size and gfx.mouse_y >= y and gfx.mouse_y <= y + size
    helpers.SetColor(active and theme.colors.btn_active or (hover and theme.colors.text or theme.colors.text_dim))
    
    local r = size / 2
    if type == "settings" then
        -- Gear Icon
        gfx.circle(x+r, y+r, r*0.5, 0, 1)
        for i=0, 7 do
            local ang = i * (math.pi/4)
            gfx.line(x+r + math.cos(ang)*r*0.5, y+r + math.sin(ang)*r*0.5, 
                     x+r + math.cos(ang)*r*0.9, y+r + math.sin(ang)*r*0.9)
        end
    elseif type == "view" then
        -- View Mode Icon (Minimal/Full toggle)
        local padding = size * 0.2
        gfx.rect(x + padding, y + padding, size - padding*2, size - padding*2, 0)
        gfx.line(x + padding, y + size/2, x + size - padding, y + size/2)
    elseif type == "help" then
        -- Help Icon (?) — círculo con signo, mismo estilo que settings/view
        gfx.circle(x+r, y+r, r*0.65, 0, 1)
        gfx.setfont(1, "Calibri", math.floor(size * 0.75))
        local qw, qh = gfx.measurestr("?")
        gfx.x, gfx.y = x + (size - qw)/2, y + (size - qh)/2 - 1
        gfx.drawstr("?")
    elseif type == "scroll" then
        -- Scroll Icon (up/down arrows)
        local cx, cy = x + r, y + r
        local a = size * 0.3
        -- Up arrow
        gfx.line(cx, cy - a*0.7, cx - a*0.5, cy - a*0.2)
        gfx.line(cx, cy - a*0.7, cx + a*0.5, cy - a*0.2)
        -- Down arrow
        gfx.line(cx, cy + a*0.7, cx - a*0.5, cy + a*0.2)
        gfx.line(cx, cy + a*0.7, cx + a*0.5, cy + a*0.2)
    elseif type == "clear" then
        -- Trash can outline (centrado verticalmente)
        local padding = size * 0.2
        local body_w = size - padding * 2
        local body_h = size * 0.48
        local body_x = x + padding
        local body_y = y + size * 0.30

        -- Lid line
        local lid_y = body_y - size * 0.04
        gfx.line(body_x - size * 0.06, lid_y, body_x + body_w + size * 0.06, lid_y)

        -- Handles on lid
        local hw = size * 0.12
        gfx.line(body_x + body_w * 0.28, lid_y, body_x + body_w * 0.28, y + size * 0.16)
        gfx.line(body_x + body_w * 0.72, lid_y, body_x + body_w * 0.72, y + size * 0.16)
        gfx.line(body_x + body_w * 0.28, y + size * 0.16, body_x + body_w * 0.72, y + size * 0.16)

        -- Body (rect open top)
        gfx.rect(body_x, body_y, body_w, body_h, 0)

        -- Inner vertical lines
        gfx.line(body_x + body_w * 0.3, body_y + size * 0.06, body_x + body_w * 0.3, body_y + body_h - size * 0.06)
        gfx.line(body_x + body_w * 0.5, body_y + size * 0.06, body_x + body_w * 0.5, body_y + body_h - size * 0.06)
        gfx.line(body_x + body_w * 0.7, body_y + size * 0.06, body_x + body_w * 0.7, body_y + body_h - size * 0.06)
    elseif type == "export" then
        -- Arrow up from tray (centrado verticalmente)
        local cx = x + size / 2
        local bottom = y + size - size * 0.22  -- tray un poco más arriba

        -- Tray (horizontal line with small vertical edges)
        gfx.line(x + size * 0.1, bottom, x + size * 0.9, bottom)
        gfx.line(x + size * 0.1, bottom, x + size * 0.1, bottom - size * 0.04)
        gfx.line(x + size * 0.9, bottom, x + size * 0.9, bottom - size * 0.04)

        -- Arrow shaft
        gfx.line(cx, bottom - size * 0.04, cx, y + size * 0.19)

        -- Arrow head
        gfx.line(cx, y + size * 0.19, cx - size * 0.22, y + size * 0.36)
        gfx.line(cx, y + size * 0.19, cx + size * 0.22, y + size * 0.36)
    end
    
    return config.state.mouse_click and hover
end

function components.DrawNoteDisplay(x, y, w, h, note)
    helpers.SetColor(theme.colors.bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)
    
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", math.floor(h * 0.7))
    local note_str = note == "None" and "-" or note
    local nw, nh = gfx.measurestr(note_str)
    gfx.x, gfx.y = x + (w - nw) / 2, y + (h - nh) / 2
    gfx.drawstr(note_str)
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

function components.DrawButton(x, y, w, h, label, active, font_size)
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    local pressed = hover and config.state.mouse_click

    -- 1. Base background: btn_bg or btn_active
    helpers.SetColor(active and theme.colors.btn_active or theme.colors.btn_bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)

    -- 2. Stroke on inactive buttons (rounded outline)
    if not active then
        helpers.SetColor(theme.colors.text_dim, 0.25)
        gfx.roundrect(x, y, w, h, 6, 0)
    end

    -- 3. Hover overlay (white semi-transparent instead of swapping bg)
    if hover and not active then
        helpers.SetColor({1, 1, 1, 0.08})
        components.DrawRoundedRect(x, y, w, h, 6, true)
    end

    -- 4. Press effect: darker top half shadow + text offset
    if pressed then
        helpers.SetColor({0, 0, 0, 0.15})
        gfx.rect(x, y, w, math.floor(h/2), 1)
    end

    -- 5. Active toggle: subtle white inner border (rounded)
    if active then
        helpers.SetColor({1, 1, 1, 0.2})
        components.DrawRoundedRect(x+1, y+1, w-2, h-2, 5, true)
        helpers.SetColor(theme.colors.btn_active)
        components.DrawRoundedRect(x+2, y+2, w-4, h-4, 4, true)
    end

    -- Label (pressed offset: +1px down)
    helpers.SetColor(active and theme.colors.text or theme.colors.text_dim)
    gfx.setfont(1, "Calibri", font_size or 12)
    local sw, sh = gfx.measurestr(label)
    local off = pressed and 1 or 0
    gfx.x, gfx.y = x+(w-sw)/2, y+(h-sh)/2 + off
    gfx.drawstr(label)

    return not config.state.drag.is_dragging and config.state.mouse_click and hover
end

function components.DrawPaginator(x, y, total_pages)
    local radius = 6
    local spacing = 24
    local start_x = x - ((total_pages - 1) * spacing) / 2
    for i = 1, total_pages do
        local cx = start_x + (i - 1) * spacing
        helpers.SetColor(config.state.current_page == i and theme.colors.page_active or theme.colors.page_inactive)
        gfx.circle(cx, y, radius, 1, 1)
        if config.state.show_tooltips then
            local dot_hover = (gfx.mouse_x - cx)^2 + (gfx.mouse_y - y)^2 <= (radius + 5)^2
            if dot_hover then
                gfx.setfont(1, "Calibri", 11)
                local label = "Page " .. i
                local lw, lh = gfx.measurestr(label)
                local tx = cx - lw/2 - 2
                local ty = y - lh - 8
                helpers.SetColor({0, 0, 0, 0.75})
                components.DrawRoundedRect(tx - 2, ty - 2, lw + 4, lh + 4, 3, true)
                helpers.SetColor(theme.colors.text)
                gfx.x, gfx.y = tx, ty
                gfx.drawstr(label)
            end
        end
        if config.state.mouse_click and (gfx.mouse_x - cx)^2 + (gfx.mouse_y - y)^2 <= radius^2 then
            config.state.current_page = i
        end
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
        local slot_color = DegreeColor(slot.degree)
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
        local nn = config.NOTE_NAMES[(midi.GetMidiNote(slot.root_index, slot.scale_index, slot.degree, slot.octave) % 12) + 1]
        local show_chord = slot.chord_mode_index > 1
        local label = show_chord and (nn .. " " .. config.CHORD_MODES[slot.chord_mode_index].name:sub(1,1):upper() .. config.CHORD_MODES[slot.chord_mode_index].name:sub(2):lower()) or nn
        
        helpers.SetColor(theme.colors.text)
        gfx.setfont(1, "Calibri", math.floor(h * 0.35))
        local nw, nh = gfx.measurestr(label)
        gfx.x, gfx.y = x+(w-nw)/2, y + (h/2) - nh
        gfx.drawstr(label)
        
        gfx.setfont(1, "Calibri", math.floor(h * 0.25))
        local deg = ROMAN_NUMERALS[slot.degree] or "?"
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
        local highlight = DegreeColor(drag_deg)
        helpers.SetColor(highlight, 0.3)
        components.DrawRoundedRect(x, y, w, h, 8, true)
    end

    -- RIGHT CLICK TO DELETE (on fresh click-down only)
    if (gfx.mouse_cap & 2) == 2 and (config.state.last_mouse_cap & 2) == 0 then
        config.state.progression[global_idx] = nil
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
            local temp = config.state.progression[global_idx]
            config.state.progression[global_idx] = config.state.progression[config.state.drag.source_slot_idx]
            config.state.progression[config.state.drag.source_slot_idx] = temp
        elseif config.state.drag.source_degree ~= -1 then
            -- NEW FROM PAD
            config.state.progression[global_idx] = { 
                degree = config.state.drag.source_degree, 
                root_index = config.state.root_index, 
                scale_index = config.state.scale_index, 
                octave = config.state.octave, 
                chord_mode_index = config.state.chord_mode_index 
            }
            config.state.slot_flash.idx = global_idx
            config.state.slot_flash.timer = 10
        end
        
        -- Cleanup immediately so DrawDragPreview doesn't see stale state
        config.state.drag.is_dragging = false
        config.state.drag.source_degree = -1
        config.state.drag.source_slot_idx = -1
        config.state.drag.pending_degree = nil
    end

    if not config.state.drag.is_dragging then
        if slot then
            local nn = config.NOTE_NAMES[(midi.GetMidiNote(slot.root_index, slot.scale_index, slot.degree, slot.octave) % 12) + 1]
            local show_chord = slot.chord_mode_index > 1
            local label = show_chord and (nn .. " " .. config.CHORD_MODES[slot.chord_mode_index].name:sub(1,1):upper() .. config.CHORD_MODES[slot.chord_mode_index].name:sub(2):lower()) or nn
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

function components.DrawDropdown(x, y, w, h, label, value, options, current_index, font_size, open_up)
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x+w and gfx.mouse_y >= y and gfx.mouse_y <= y+h
    helpers.SetColor(theme.colors.bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)
    
    -- Adaptive Text Logic: progressive font reduction, then dynamic truncation
    local function GetFitText(str, max_w, f_size)
        local s = str:gsub("%s*%b()", "")
        -- Try full size first
        gfx.setfont(1, "Calibri", f_size)
        if gfx.measurestr(s) <= max_w then return s, f_size end
        -- Step down font size until it fits
        for size = f_size - 1, 8, -1 do
            gfx.setfont(1, "Calibri", size)
            if gfx.measurestr(s) <= max_w then return s, size end
        end
        -- Truncate at smallest font
        gfx.setfont(1, "Calibri", 8)
        for len = #s - 1, 1, -1 do
            local t = s:sub(1, len) .. ".."
            if gfx.measurestr(t) <= max_w then return t, 8 end
        end
        return "..", 8
    end

    local final_text, final_size = GetFitText(value, w - 25, font_size or 12)
    helpers.SetColor(theme.colors.text)
    gfx.setfont(1, "Calibri", final_size)
    local vw, vh = gfx.measurestr(final_text)
    gfx.x, gfx.y = x + 10, y + (h-vh)/2
    gfx.drawstr(final_text)
    
    helpers.SetColor(theme.colors.btn_active)
    local cx, cy = x + w - 15, y + h/2
    for i=0, 1 do
        gfx.line(cx-4, cy-2+i, cx, cy+2+i, 1)
        gfx.line(cx, cy+2+i, cx+4, cy-2+i, 1)
    end
    
    -- Scroll wheel selection
    if hover and config.state.use_scroll and config.state.mouse_wheel_delta ~= 0 then
        local delta = config.state.mouse_wheel_delta > 0 and -1 or 1
        config.state.mouse_wheel_delta = 0
        local new_idx = current_index + delta
        if new_idx < 1 then new_idx = #options end
        if new_idx > #options then new_idx = 1 end
        return new_idx
    end
    
    if hover and config.state.mouse_click then
        local menu_str = ""
        for i, opt in ipairs(options) do
            local safe_opt = opt:gsub("|", "·")
            menu_str = menu_str .. (i == current_index and "!" or "") .. safe_opt .. "|"
        end
        if open_up then
            gfx.x, gfx.y = x, y
        else
            gfx.x, gfx.y = x, y + h
        end
        local choice = gfx.showmenu(menu_str:sub(1, -2))
        if choice > 0 then return choice end
    end
    return nil
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
                helpers.SetColor(DegreeColor(deg), 0.7)
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
            local glow = deg and DegreeColor(deg) or {1, 1, 1, 0.3}
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
                helpers.SetColor(DegreeColor(deg), 0.7)
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
            local glow = deg and DegreeColor(deg) or {1, 1, 1, 0.4}
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
    local rn = midi.GetMidiNote(config.state.root_index, config.state.scale_index, degree, config.state.octave)
    local chord_type = config.CHORD_MODES[config.state.chord_mode_index].name
    -- Bug fix: in Note mode (index 1 = "Off"), show only the note name, no chord suffix
    local note_name = config.NOTE_NAMES[(rn % 12) + 1]
    local label = config.state.chord_mode_index == 1 and note_name or (note_name .. " " .. chord_type:sub(1,1):upper() .. chord_type:sub(2):lower())
    local roman = ROMAN_NUMERALS[degree]
    
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
        helpers.SetColor(DegreeColor(degree), active and 1 or 0.9)
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
        preview_color = DegreeColor(config.state.drag.source_degree)
    elseif config.state.drag.source_slot_idx ~= -1 then
        local src_slot = config.state.progression[config.state.drag.source_slot_idx]
        if src_slot then
            preview_color = DegreeColor(src_slot.degree)
        end
    end
    helpers.SetColor(preview_color, 0.8)
    components.DrawRoundedRect(x, y, cw, ch, 8, true)

    helpers.SetColor(theme.colors.text)

    if config.state.drag.source_degree ~= -1 then
        -- Dragging from a pad: show actual note name + roman numeral
        local degree = config.state.drag.source_degree
        local rn = midi.GetMidiNote(config.state.root_index, config.state.scale_index, degree, config.state.octave)
        local note_name = config.NOTE_NAMES[(rn % 12) + 1]
        local show_chord = config.state.chord_mode_index > 1
        local label = show_chord and (note_name .. " " .. config.CHORD_MODES[config.state.chord_mode_index].name:sub(1,1):upper() .. config.CHORD_MODES[config.state.chord_mode_index].name:sub(2):lower()) or note_name
        local roman = ROMAN_NUMERALS[degree]

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
            local nn = config.NOTE_NAMES[(midi.GetMidiNote(slot.root_index, slot.scale_index, slot.degree, slot.octave) % 12) + 1]
            local show_chord = slot.chord_mode_index > 1
            local label = show_chord and (nn .. " " .. config.CHORD_MODES[slot.chord_mode_index].name:sub(1,1):upper() .. config.CHORD_MODES[slot.chord_mode_index].name:sub(2):lower()) or nn
            local roman = ROMAN_NUMERALS[slot.degree] or "?"

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

-- Compact pill button for docked transport bar (38px height)
function components.DrawTransportButton(label, x, y, w, h)
    local hover = gfx.mouse_x >= x and gfx.mouse_x <= x + w and gfx.mouse_y >= y and gfx.mouse_y <= y + h

    helpers.SetColor(hover and theme.colors.btn_hover or theme.colors.btn_bg)
    components.DrawRoundedRect(x, y, w, h, 6, true)

    helpers.SetColor(theme.colors.text_dim)
    gfx.setfont(1, "Calibri", 11)
    local lw, lh = gfx.measurestr(label)
    gfx.x, gfx.y = x + (w - lw) / 2, y + (h - lh) / 2
    gfx.drawstr(label)

    return config.state.mouse_click and hover
end

return components
