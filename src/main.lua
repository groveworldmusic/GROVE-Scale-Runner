-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 Andrik Sanz Cordoví
-- @description Scale Runner — QWERTY to MIDI Controller for REAPER
-- @version 1.0.0
-- @author GROVE WORLD MUSIC
-- @about
--   Scale Runner is a QWERTY-to-MIDI controller for REAPER.
--   Maps keyboard keys to scale degrees and chord modes for
--   intuitive music performance and composition.
--   Features include:
--     • Sequencer with step-by-step playback
--     • Piano keyboard UI with scale highlighting
--     • Performance pads with drag-to-slot interaction
--     • Progression slots with page navigation
--     • Dockable transport bar and compact overlay mode
--     • MIDI Island for advanced editing
--     • Preset browser, velocity editor, piano roll
--     • Snap grid and velocity humanization
-- @provides
--   [main] src/main.lua
--   src/config.lua
--   -- core/
--   src/core/api-guard.lua
--   src/core/keyboard.lua
--   src/core/midi.lua
--   src/core/progression.lua
--   src/core/sequencer.lua
--   src/core/snap.lua
--   -- state/
--   src/state/compact.lua
--   src/state/drag.lua
--   src/state/island.lua
--   src/state/midi.lua
--   src/state/note-store.lua
--   src/state/preset-store.lua
--   src/state/persist.lua
--   src/state/sequencer.lua
--   src/state/ui.lua
--   -- ui/
--   src/ui/slots.lua
--   src/ui/buttons.lua
--   src/ui/colors.lua
--   src/ui/compact.lua
--   src/ui/compact-bar.lua
--   src/ui/compact-init.lua
--   src/ui/compact-intercept.lua
--   src/ui/compact-menu.lua
--   src/ui/compact-panel.lua
--   src/ui/components.lua
--   src/ui/drag.lua
--   src/ui/dropdown.lua
--   src/ui/format.lua
--   src/ui/gfx-safe.lua
--   src/ui/helpers.lua
--   src/ui/layout.lua
--   src/ui/lice.lua
--   src/ui/pads.lua
--   src/ui/paginator.lua
--   src/ui/piano.lua
--   src/ui/piano-roll.lua
--   src/ui/piano-roll/grid.lua
--   src/ui/piano-roll/interaction.lua
--   src/ui/piano-roll/note.lua
--   src/ui/piano-roll/view.lua
--   src/ui/positioning.lua
--   src/ui/preset-browser.lua
--   src/ui/theme.lua
--   src/ui/timeline.lua
--   src/ui/velocity.lua
--   src/ui/views.lua
-- @changelog
--   v1.0.0 2026-05-13
--     + Professional polish: license headers, API guards, ReaPack metadata
--     + Production-ready polish: naming standardization, documentation
-- @website https://github.com/GroveWorldMusic/GROVE-Scale-Runner

local info = debug.getinfo(1, 'S')
local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]])
if not script_path then
    reaper.MB("Could not determine script path.", "Error", 0)
    return
end
package.path = package.path .. ";" .. script_path .. "?.lua"

local config = require("config")
local api_guard = require("core.api-guard")
local compact_store = require("state.compact")
compact_store.Init(config.state)
local drag_store = require("state.drag")
drag_store.Init(config.state)
local sequencer_store = require("state.sequencer")
sequencer_store.Init(config.state)
local midi_store = require("state.midi")
midi_store.Init(config.state)
local ui_store = require("state.ui")
ui_store.Init(config.state)
-- view_offset_x/y now live in ui_store (migrated from config.state)
ui_store.SetViewOffsetX(config.state.view_offset_x or 0)
ui_store.SetViewOffsetY(config.state.view_offset_y or 0)
local island_store = require("state.island")
island_store.Init(config.state)
local note_store = require("state.note-store")
-- note_store.Init is called inside island_store.Init(config.state)
local preset_store = require("state.preset-store")
preset_store.Init(config.state)
local preferences_store = require("state.preferences")
preferences_store.Init(config.state)
local theme = require("ui.theme")
local midi = require("core.midi")
local sequencer = require("core.sequencer")
local views = require("ui.views")
local compact = require("ui.compact")
local keyboard = require("core.keyboard")
local vkey_map = require("core.vkey-map")
local midi_input = require("core.midi-input")
local persist = require("state.persist")
local gfx_safe = require("ui.gfx-safe")

local last_dock_state = 0
local _last_persisted_vx = 0  -- tracking for view_offset_x/y persist
local _last_persisted_vy = 0
local gfx_needs_redraw = true  -- dirty flag: skip GFX redraw when nothing visual changed

-- Toggle dock state (Ctrl+D)
local function ToggleDock()
    if ui_store.GetDockedMode() then
        -- Undock: call gfx.dock(0) to float
        gfx.dock(0)
        ui_store.SetDockedMode(false)
        ui_store.SetDockId(0)
        -- Resize back to normal window
        gfx_safe.SafeGfxInit(config.script_title, 720, 497, 0, ui_store.GetViewOffsetX(), ui_store.GetViewOffsetY())
    else
        -- Dock: call gfx.dock(1) to dock in transport bar slot
        ui_store.SetDockId(gfx.dock(1))
        if ui_store.GetDockId() > 0 then
            ui_store.SetDockedMode(true)
        else
            ui_store.SetDockId(0)
        end
    end
end

-- Toggle view mode (Ctrl+Shift+C) - called from HandleKeyboard
local function ToggleViewMode()
    compact.SwitchViewMode()
end

-- Check dock state changes (polling via gfx.dock(-1))
local function CheckDockState()
    local current_dock = gfx.dock(-1)
    if current_dock ~= last_dock_state then
        last_dock_state = current_dock
        if current_dock > 0 then
            ui_store.SetDockedMode(true)
            ui_store.SetDockId(current_dock)
        else
            ui_store.SetDockedMode(false)
            ui_store.SetDockId(0)
        end
    end
end



-- =========================================================
-- AUTO TRACK SETUP
-- =========================================================
-- Every time the user selects a track, auto-arm, enable monitoring,
-- and set MIDI input to Virtual MIDI Keyboard.

--- I_RECINPUT value for Virtual MIDI Keyboard, all MIDI channels.
--- Bit layout: 4096 (MIDI flag) | (62 << 5) (VKB physical input) | 0 (all channels)
local VKB_RECINPUT = 6080  -- 0x17C0 = 4096 | 1984

--- Track selection tracking for auto-setup.
local last_sel_track_ptr = nil

--- Track that was configured by the script, for restoration on deselection.
local last_configured_track = nil

--- Disarm and reset a previously configured track when deselected.
local function RestorePreviousTrack()
    if not last_configured_track then return end
    -- Validate the track pointer (may be stale if track was deleted)
    if not reaper.ValidatePtr(last_configured_track, "MediaTrack*") then
        last_configured_track = nil
        return
    end
    reaper.SetMediaTrackInfo_Value(last_configured_track, "I_RECARM", 0)
    reaper.SetMediaTrackInfo_Value(last_configured_track, "I_RECMON", 0)
    last_configured_track = nil
end

--- Apply auto-setup to a track: arm + monitoring ON + Virtual MIDI Keyboard input.
local function ApplyTrackSetup(tr)
    if not tr then return end
    reaper.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
    reaper.SetMediaTrackInfo_Value(tr, "I_RECMON", 2)
    reaper.SetMediaTrackInfo_Value(tr, "I_RECINPUT", VKB_RECINPUT)
    reaper.TrackList_AdjustWindows(false)  -- force UI refresh
    last_configured_track = tr
end

--- Auto-setup: called every time the script starts.
--- Restores any previous track, then configures the current selection.
local function AutoSetupTrack()
    RestorePreviousTrack()
    local tr = reaper.GetSelectedTrack(0, 0)
    ApplyTrackSetup(tr)
    last_sel_track_ptr = tr
end

local function CleanupAll()
    sequencer.Stop()  -- Stop sequencer FIRST so note-offs are sent via ref-counted notes
    midi.AllNotesOff(true)  -- force=true: bypasses ref-count gate on cleanup (belt + suspenders)
    keyboard.Cleanup()
    midi_input.Cleanup()  -- finalize any open recording notes
    compact.Cleanup()
end

local function MainLoop()
    -- Auto Track Setup: detect track selection change (works in ALL modes)
    if ui_store.GetAutoTrackSetup() then
        local sel_tr = reaper.GetSelectedTrack(0, 0)
        if sel_tr ~= last_sel_track_ptr then
            last_sel_track_ptr = sel_tr
            RestorePreviousTrack()          -- restore old track to original state
            ApplyTrackSetup(sel_tr)         -- configure new track
        end
    end

    -- Decrement note display timer
    if midi_store.GetActiveNoteDrawTimer() > 0 then
        midi_store.SetActiveNoteDrawTimer(midi_store.GetActiveNoteDrawTimer() - 1)
    end

    -- Decrement page override timer in ALL modes (Issue 8)
    views.DecrementPageOverrideTimer()
    
    -- Shared logic for ALL modes
    keyboard.CheckFocus()
    sequencer.Run()
    keyboard.HandleKeyboard()
    midi_input.Poll()  -- record MIDI input when armed (no-op if disarmed)
    preferences_store.TickSaveDebounce()
    sequencer_store.TickVolumeSave()  -- debounced volume persist (slider drag)

    -- Compact mode (no GFX window)
    if ui_store.GetViewMode() == config.VIEW_MODES.COMPACT then
        compact.ProcessMouseInterception()
        compact.UpdateCompactView()
        compact.HandlePanel()
        reaper.defer(MainLoop)
        return
    end

    -- Overlay mode: compact bar visible alongside full view (auto-start)
    if compact_store.GetOverlayActive() then
        compact.ProcessMouseInterception()
        compact.UpdateCompactView()
        -- Si TogglePanel se disparó (clic en la barra → panel_open = true),
        -- no podemos dibujar el panel sin conflicto de GFX. Transicionamos a
        -- compacto completo: gfx.quit() cierra la full view, luego HandlePanel
        -- en el próximo frame crea la ventana del panel (panel_open ya es true).
        if compact.IsPanelOpen() then
            compact.SwitchViewMode()  -- overlay_active=false, view_mode=COMPACT, gfx.quit()
        end
        if ui_store.GetViewMode() == config.VIEW_MODES.COMPACT then
            reaper.defer(MainLoop)
            return
        end
    end

    -- GFX mode: mouse state + GFX calls
    local mwd = gfx.mouse_wheel
    local current_mouse_cap = gfx.mouse_cap
    local fresh_click = (current_mouse_cap & 1) == 1 and ui_store.GetLastMouseCap() == 0
    ui_store.SetMouseClick(fresh_click)
    ui_store.SetMouseWheelDelta(mwd)
    gfx.mouse_wheel = 0

    -- Check mouse movement
    local mx, my = gfx.mouse_x, gfx.mouse_y
    if mx ~= ui_store.GetLastMouseX() or my ~= ui_store.GetLastMouseY() then
        ui_store.SetLastMouseX(mx)
        ui_store.SetLastMouseY(my)
        gfx_needs_redraw = true
    end

    -- Check mouse button state changes
    if current_mouse_cap ~= ui_store.GetLastMouseCap() then
        gfx_needs_redraw = true
    end

    -- Force an extra redraw frame after a click to ensure state changes are reflected
    if ui_store.GetForceNextRedraw() then
        gfx_needs_redraw = true
        ui_store.SetForceNextRedraw(false)
    end
    if fresh_click then
        ui_store.SetForceNextRedraw(true)
    end

    -- Dirty-flag: set to true when any visual state changes
    if mwd ~= 0 then gfx_needs_redraw = true end
    -- Always redraw while sequencer is running, notes are dirty, or timers are active (state changes every frame)
    if sequencer_store.GetIsPlaying() then gfx_needs_redraw = true end
    if midi_store.GetActiveNoteDrawTimer() > 0 then gfx_needs_redraw = true end
    if sequencer_store.GetPageOverrideTimer() > 0 then gfx_needs_redraw = true end
    -- Notes state: force redraw when notes are modified (drag, nudge, undo/redo, paint, knife)
    -- Tri-state: EDITED and SYNCED both need redraw; LOADED means fresh from progression (no redraw needed for this flag alone).
    -- SYNCED is a one-shot event — force one redraw then revert to LOADED so the dirty flag doesn't stay stuck on.
    local ns = island_store.GetNotesState()
    if ns ~= island_store.NOTES_STATE_LOADED then
        gfx_needs_redraw = true
        if ns == island_store.NOTES_STATE_SYNCED then
            island_store.ResetNotesState()
        end
    end

    local prev_dock = last_dock_state
    CheckDockState()
    if prev_dock ~= last_dock_state then gfx_needs_redraw = true end

    local char = gfx.getchar()
    ui_store.SetLastChar(char)  -- Expose to preset browser search and other consumers

    -- Only redraw GFX when something visual changed, but always call gfx.getchar() for responsiveness
    local esc_consumed = false
    if gfx_needs_redraw then
        if ui_store.GetDockedMode() then
            views.DrawDockedTransportBar(gfx.w, gfx.h)
        else
            esc_consumed = views.DrawFullView(char)
        end
        gfx_needs_redraw = false
    end

    ui_store.SetLastMouseCap(gfx.mouse_cap)

    -- Window dimension persistence: poll gfx.w/gfx.h and save on change
    if gfx.w and gfx.w > 0 and gfx.w ~= ui_store.GetLastWindowW() then
        ui_store.SetLastWindowW(gfx.w)
        persist.Save("window_w", gfx.w)
    end
    if gfx.h and gfx.h > 0 and gfx.h ~= ui_store.GetLastWindowH() then
        ui_store.SetLastWindowH(gfx.h)
        persist.Save("window_h", gfx.h)
    end

    -- Re-check: DrawFullView may have called SwitchViewMode() or midi.ToggleIsland()
    if ui_store.GetViewMode() == config.VIEW_MODES.COMPACT then
        reaper.defer(MainLoop)
        return
    end
    if island_store.GetMidiIslandToggled() then
        island_store.SetMidiIslandToggled(false)
        gfx_needs_redraw = true  -- window was recreated by gfx.quit()+gfx.init()
        reaper.defer(MainLoop)
        return
    end

    -- Keep window position current at ALL times while island is expanded,
    -- even during drag. The only frame we can't capture is the enforcement
    -- frame itself (gfx.quit destroys the HWND). Validated against garbage
    -- values (stale booleans from old gfx-window.lua bug, or extreme coords).
    -- Also runs on first frame to sanitize stale config.state values.
    if gfx.hwnd then
        local _, l, t = reaper.JS_Window_GetRect(gfx.hwnd)
        if type(l) == "number" and l > -10000 and l < 10000 then
            ui_store.SetViewOffsetX(l)
            ui_store.SetViewOffsetY(t)
        end
    end

    -- Persist window position on change (same pattern as window_w/h save)
    local cur_vx = ui_store.GetViewOffsetX()
    local cur_vy = ui_store.GetViewOffsetY()
    if cur_vx ~= _last_persisted_vx then
        persist.Save("view_offset_x", cur_vx)
        _last_persisted_vx = cur_vx
    end
    if cur_vy ~= _last_persisted_vy then
        persist.Save("view_offset_y", cur_vy)
        _last_persisted_vy = cur_vy
    end

    -- Window size enforcement: width fixed at 720px always.
    -- Height minimum: 793px when island expanded, 497px when collapsed.
    -- Título temporal único evita que REAPER use posición cacheada en gfx.ini.
    local min_h = island_store.GetMidiIslandExpanded() and 793 or 497
    if gfx.h and gfx.h > 100 and (math.abs(gfx.w - 720) > 1 or gfx.h < min_h) then
        local uid = config.script_title .. reaper.time_precise()
        gfx.quit()
        gfx.init(uid, 720, min_h, 0,
                 ui_store.GetViewOffsetX(), ui_store.GetViewOffsetY())
        gfx.setfont(1, "Calibri", 16)
        if reaper.JS_Window_SetTitle then
            reaper.JS_Window_SetTitle(gfx.hwnd, config.script_title)
        end
        gfx_needs_redraw = true
    end

    -- Ctrl+D toggle dock
    if char == 4 then
        ToggleDock()
    end
    if char == -1 or (char == 27 and not esc_consumed) then
        if ui_store.GetDidCleanup() then return end
        ui_store.SetDidCleanup(true)
        CleanupAll()
        gfx_safe.SafeGfxQuit()
        return
    end
    reaper.defer(MainLoop)
end

local function Init()
    -- Verify required JS_ReaScriptAPI extension
    if not api_guard.AssertAPIs({
        JS_Window_Find = "JS_Window_Find — required for window management",
        JS_VKeys_GetState = "JS_VKeys_GetState — required for keyboard interception",
        JS_VKeys_Intercept = "JS_VKeys_Intercept — required for keyboard interception",
        JS_Window_GetRect = "JS_Window_GetRect — required for window positioning",
        JS_Window_GetClientSize = "JS_Window_GetClientSize — required for window sizing",

        JS_LICE_CreateBitmap = "JS_LICE_CreateBitmap — required for compact view rendering",
        JS_Composite = "JS_Composite — required for compact view overlay",
    }) then return end

    -- Register cleanup for safe exit
    ui_store.SetDidCleanup(false)
    reaper.atexit(function()
        if ui_store.GetDidCleanup() then return end
        ui_store.SetDidCleanup(true)
        CleanupAll()
    end)

    -- Load persisted preferences from REAPER ExtState (canonical with legacy fallback)
    persist.Load(config.state)
    preferences_store.SyncFromState(config.state)
    -- Apply persisted theme after SyncFromState (theme.lua loaded earlier with default idx)
    theme.SetThemeIndex(preferences_store.GetThemeIndex())
    -- Initialize vkey-map with persisted overlay (reads config.state.vkey_map_raw)
    vkey_map.Init(config.state)
    keyboard.RebuildKeyStates()

    -- Restore persisted volume into sequencer store (persist.Load writes to config.state,
    -- but the sequencer store has its own copy that was initialized before persist.Load)
    sequencer_store.SetVolume(config.state.sequencer.volume or 100)
    -- Issue A7: sync use_scroll from config.state into ui_store after persist.Load
    ui_store.SetUseScroll(config.state.use_scroll)

    -- Sync view offset from persisted config.state into ui_store (persist.Load
    -- wrote to config.state, but ui_store was initialized before persist.Load ran)
    ui_store.SetViewOffsetX(config.state.view_offset_x or 0)
    ui_store.SetViewOffsetY(config.state.view_offset_y or 0)

    -- Load persisted window dimensions from ExtState
    local ext_win_w = reaper.GetExtState("GROVE_Scale_Runner", "window_w")
    if ext_win_w ~= "" then
        local nw = tonumber(ext_win_w)
        if nw and nw >= 400 then ui_store.SetLastWindowW(nw) end
    end
    local ext_win_h = reaper.GetExtState("GROVE_Scale_Runner", "window_h")
    if ext_win_h ~= "" then
        local nh = tonumber(ext_win_h)
        if nh and nh >= 400 then ui_store.SetLastWindowH(nh) end
    end

    gfx_safe.SafeGfxInit(config.script_title, 720, 497, 0, ui_store.GetViewOffsetX(), ui_store.GetViewOffsetY())
    gfx.setfont(1, "Calibri", 16)

    -- Load extra auto-start preferences from REAPER ExtState
    local ext_compact = reaper.GetExtState("GROVE_Scale_Runner", "auto_start_compact")
    if ext_compact == "1" then ui_store.SetAutoStartCompact(true) end
    local ext_reaper = reaper.GetExtState("GROVE_Scale_Runner", "auto_start_reaper")
    if ext_reaper == "1" then ui_store.SetAutoStartReaper(true) end
    local ext_track = reaper.GetExtState("GROVE_Scale_Runner", "auto_track_setup")
    if ext_track == "0" then ui_store.SetAutoTrackSetup(false) end

    -- Auto Track Setup: configure selected track (only if enabled in settings)
    if ui_store.GetAutoTrackSetup() then
        AutoSetupTrack()
    end

    -- Auto-start: compact bar overlay alongside full view
    if ui_store.GetAutoStartCompact() then
        compact.InitOverlay()
    end

    -- Auto-start: register as REAPER startup script if enabled
    if ui_store.GetAutoStartReaper() then
        local resource_path = reaper.GetResourcePath()
        if resource_path and #resource_path > 0 then
            local startup_dir = resource_path .. "\\Scripts\\Startup\\"
            local startup_file = startup_dir .. "GROVE_Scale_Runner.lua"

            local f = io.open(startup_file, "r")
            if not f then
                -- Derive absolute path to this script
                local info = debug.getinfo(1, 'S')
                local our_path = (info.source or ""):gsub("^@", "")  -- strip @ prefix

                -- Ensure Startup directory exists
                reaper.RecursiveCreateDirectory(startup_dir, 0)

                -- Create wrapper script that dofile()s the real main.lua
                local fh = io.open(startup_file, "w")
                if fh then
                    local escaped = our_path:gsub("\\", "\\\\")
                    fh:write("-- Auto-start for GROVE Scale Runner\n")
                    fh:write("-- REAPER runs all .lua files in Scripts/Startup/ at launch\n")
                    fh:write("dofile[[" .. escaped .. "]]\n")
                    fh:close()
                end
            else
                f:close()
            end
        end
    end

    reaper.defer(MainLoop)
end

Init()
