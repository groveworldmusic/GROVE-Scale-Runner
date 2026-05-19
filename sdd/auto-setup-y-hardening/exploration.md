## Exploration: Auto Track Setup + Production Hardening

### Current State

The script (`src/main.lua`) sends MIDI via `reaper.StuffMIDIMessage()` into REAPER's virtual MIDI port. This output reaches a VST/audio only when a track is:

1. **Record-armed** (I_RECARM=1)
2. **Monitoring enabled** (I_RECMON=1 for normal, or =2 for auto)
3. **Input set** to "Virtual MIDI Keyboard" or "All MIDI Inputs"

**Zero auto-setup code exists currently.** The only REAPER track APIs used are in `ExportToMidi()` (midi.lua line 119): `GetSelectedTrack`, `InsertTrackAtIndex`, `GetTrack`. No calls to `GetSetMediaTrackInfo`, `GetNumTracks`, or any input-routing API.

The script checks for `js_ReaScriptAPI` on startup (main.lua line 201) but does NOT verify track configuration. Users must manually configure a track every time they run the script in a new project.

### Hardening: Code Quality Findings

The codebase is mature (post-phase-3d refactor) with good patterns (ref-counted notes, event bus, lazy require). However, several gaps were found:

#### CRITICAL: Ref-counted Active Notes — Premature Note-Off

**Where**: `src/core/midi.lua` lines 25-47 (`SendMidi`)

**The problem**: The ref-counted pattern correctly tracks `active_notes[note]` counts, but does NOT gate MIDI output. The `reaper.StuffMIDIMessage()` call at line 30 executes BEFORE the ref-counting logic:

```lua
function midi.SendMidi(note, on, velocity)
    ...
    reaper.StuffMIDIMessage(ch, on and 0x90 or 0x80, note, on and vel or 0)  -- ALWAYS sends
    if on then
        ... increment ref count ...
    else
        ... decrement ref count ...  -- note-off sent regardless of remaining refs
    end
end
```

**Concrete scenario**: Pad + keyboard trigger the same chord (e.g., degree 1 Tri in C Major → notes 60, 64, 67). Both hold. Ref count = 2. When the pad is released (`pads.lua` line 122-124 sends `midi.SendMidi(n, false)` for each note), the MIDI note-off IS sent even though ref=2→1. The VST stops playing while the keyboard is still held.

**Impact**: Premature note cutoff, NOT stuck notes. Worse than silent — it's an audible glitch.

**Tests**: `test_sendmidi.lua` lines 90-115 verify the ref-count TABLE state is correct (2→1→nil), but never assert that the MIDI message is suppressed when refs > 0. The tests match the CURRENT (buggy) behavior.

**Fix**: Move `reaper.StuffMIDIMessage(ch, 0x80, note, 0)` inside the `if cur <= 0` block. Only send note-off when ref count reaches 0. For force/cleanup paths (AllNotesOff, sequencer.Stop), add a `force` parameter or use a separate bypass.

#### CRITICAL: Sequencer Catch-Up Produces Audible Clicks

**Where**: `src/core/sequencer.lua` lines 94-113

When a frame is delayed, the catch-up loop calls `midi.TriggerChord(slot, true, ...)` (sends note-ons) then immediately `midi.SendMidi(n, false)` (sends note-offs) for each skipped measure. This produces a brief MIDI note-on/note-off pulse — audible as a click.

**Fix**: Skip TriggerChord for catch-up measures. Just update the store state without sending MIDI. Or use a dedicated silent function that only updates ref counts.

#### CRITICAL: VIEW_MODES.ISLAND Missing from config

**Where**: `src/config.lua` line 44, `src/ui/compact-init.lua` line 60

config.lua defines `VIEW_MODES = { FULL = 1, COMPACT = 2 }` — no ISLAND entry. But `compact-init.lua` line 60 checks:

```lua
if ui_store.GetViewMode() == config.VIEW_MODES.ISLAND then  -- ISLAND is nil!
```

`config.VIEW_MODES.ISLAND` is `nil`. This comparison is ALWAYS false (unless view_mode itself is nil, which would break everything). The ISLAND→FULL transition in `SwitchViewMode()` is entirely dead code.

**Impact**: If any future code sets `view_mode` to a third state (ISLAND = 3), the transition back to FULL won't work. Or if it was meant to work and never got wired up, it's a latent bug.

#### MODERATE: AllNotesOff / Stop Must Be Called Together

**Where**: `src/core/midi.lua` lines 91-116 (AllNotesOff), `src/core/sequencer.lua` lines 8-19 (Stop)

`AllNotesOff()` explicitly avoids calling `sequencer.Stop()` (comment at line 114). And `Stop()` does its own note-offs from `seq_store.GetMidiNotes()`. If only one is called:

- Only `AllNotesOff()` → sequencer-held notes in `MidiNotes` are NOT released (no note-off sent for those MIDI notes). The MIDI note-ons would hang.
- Only `Stop()` → keyboard/pad-held notes are NOT released.

`main.lua`'s `CleanupAll()` correctly calls BOTH. But other callers must remember this contract.

**Check callers**:
- `CheckFocus` (keyboard.lua line 87): calls only `AllNotesOff()` — sequencer notes could hang if sequencer is running when focus is lost! This IS a real bug.
- `pads.lua` line 69: calls `midi.SendMidi(n, false)` directly — this is fine since it's releasing specific notes.

**Fix**: Either `AllNotesOff` should call `sequencer.Stop()` (but this creates circular dep), OR `CheckFocus` must also call `sequencer.Stop()`.

#### MODERATE: Focus Race in 0.2s Throttle Window

**Where**: `src/core/keyboard.lua` lines 74-90 (CheckFocus)

`CheckFocus` throttles to 0.2s between checks. If focus is lost and regained within that window, the script misses both transitions. `is_intercepting` would be stale — if focus returned, intercept is already active (wasn't released), so `CheckFocus` sees `should_intercept=true AND is_intercepting=true` → no-op (correct for gain). If focus was lost and returned within 0.2s, the release at loss is missed, but the intercept stays active through the entire window, which is fine for usability — the user just doesn't lose keyboard control during a rapid alt-tab.

**Impact**: Low. The worst case is notes hang for up to 0.2s on focus loss before AllNotesOff fires.

#### LOW: InterceptMappedKeys Called Twice at Startup

**Where**: `src/main.lua` line 224, `src/core/keyboard.lua` line 82

`Init()` calls `keyboard.InterceptMappedKeys(false)` at line 224 — clean slate. Then the first `MainLoop` frame calls `keyboard.CheckFocus()` which may call `InterceptMappedKeys(true)`. This is redundant but harmless — JS_VKeys_Intercept with action=1 on already-intercepted keys is a no-op.

#### LOW: Lazy Requires Inside Per-Frame Hot Path

**Where**: `src/ui/compact-intercept.lua` lines 46, 73, 84, 87, 104, 110

`ProcessMouseInterception()` has `require("ui.compact-init")`, `require("ui.compact-menu")`, `require("ui.compact-panel")` called EVERY frame inside if-blocks. Lua's `require()` caches modules after first load, so this is actually just a table lookup after the first call. Not a performance issue — just looks risky.

#### LOW: ExportToMidi — Nil Take Crash

**Where**: `src/core/midi.lua` line 138

```lua
local item = reaper.CreateNewMIDIItemInProj(track, ...)
local take = reaper.GetActiveTake(item)
```

If `CreateNewMIDIItemInProj` returns nil (e.g., invalid track, corrupt project state), `GetActiveTake(nil)` crashes. No pcall guard.

#### LOW: Inconsistent ExtState Key Names

**Where**: `src/main.lua` vs `src/ui/preset-browser.lua`

- Main: `"GROVE_Scale_Runner"` (underscore, "Runner")
- Preset browser: `"GROVE_FL_MIDI"` (different key, "MIDI")

They're in different namespaces (auto-start vs preset favorites) but inconsistent.

### Approaches — Auto Track Setup

#### 1A: Full Auto-Configure on Launch

Create a dedicated "GROVE" track if none with the right setup exists. Sets I_RECARM=1, I_RECMON=1 (or 2), I_RECINPUT to Virtual MIDI Keyboard.

**REAPER API needed**:
- `reaper.GetNumTracks()` / `reaper.GetTrack(0, i)`
- `reaper.GetSetMediaTrackInfo(track, "I_RECARM", 1)` — arm
- `reaper.GetSetMediaTrackInfo(track, "I_RECMON", 1)` — monitor on
- `reaper.GetSetMediaTrackInfo(track, "I_RECINPUT", 0x10000000)` — Virtual MIDI Keyboard (all channels)
- Or `reaper.BR_GetSetTrackInput()` from SWS for more control

**Pros**: One-click setup. No user friction. Handles first-run and new-project scenarios.

**Cons**: Modifies project state without user consent. Track creation is a side effect. User might not want a dedicated track. Requires understanding REAPER's input routing bitmask (I_RECINPUT is a packed int: `(input_type << 16) | channel`).

**Effort**: Medium — needs new core module `setup.lua` or extend `main.lua Init()`.

#### 1B: Check + Guided Prompt

On first launch (per project), check if ANY track is properly configured. If not, show a dialog with instructions and optionally offer to auto-configure.

**Pros**: Less intrusive. User stays in control. Educational for new users.

**Cons**: Two-step friction. Dialog every new project? (Need per-project persistence.)

**Effort**: Low — simple check in Init(), message box or custom dialog.

#### 1C: Minimal — Warning Only

Check if setup is correct. If not, log a warning to REAPER console or show a brief message. Don't auto-configure.

**Pros**: Zero side effects. Simplest code. Full user control.

**Cons**: Worst UX. User must still do the manual steps. They already asked to automate this.

#### 1D: Use SWS ExtState to Persist Setup Preference

Remember per-project whether auto-setup has been applied. Skip subsequent checks on the same project.

**Pros**: Avoids repeated setup prompts. Pairs well with any approach above.

**Cons**: Requires managing REAPER ExtState per project.

### Recommendation

**For Auto Setup**: Recommend **Approach 1A (full auto-configure)** paired with a **nag-once dialog** that says "GROVE needs a track to send MIDI. Auto-configure?" with Yes/No. On Yes: create+arm+monitor a track. Store in ExtState to skip on future runs. This gives one-click convenience while respecting user consent.

**For Hardening**: Fix in this order:
1. **CRITICAL**: Ref-counted note-off gating in `midi.SendMidi` — move the 0x80 call inside the `cur <= 0` block
2. **CRITICAL**: Sequencer catch-up click prevention — skip TriggerChord in catch-up loop, just update state
3. **CRITICAL**: Add VIEW_MODES.ISLAND to config.lua or remove dead code
4. **MODERATE**: Fix CheckFocus — call `sequencer.Stop()` on focus loss
5. **LOW**: Add pcall guard in ExportToMidi

### Risks

- **Ref-count fix changes midi.SendMidi behavior**: AllNotesOff and Stop send note-offs unconditionally. The ref-count gate would block those too. Solution: add `force` param to SendMidi, or use a different path for cleanup.
- **Auto-setup on wrong track**: If the user already has a configured track, creating a new one could confuse their routing. Solution: scan existing tracks first for correct setup.
- **REAPER version differences**: I_RECINPUT bitmask changed between REAPER versions. Virtual MIDI Keyboard input ID may differ. Need to test on target REAPER versions.
- **SWS dependency for BR_* functions**: Prefer native `GetSetMediaTrackInfo` over SWS extensions to avoid adding dependencies.

### Ready for Proposal

**Yes** — exploration is complete. The orchestrator should tell the user there are **3 critical bugs** found in the hardening audit (ref-count note-off gating, sequencer catch-up clicks, VIEW_MODES.ISLAND dead code) plus 3 moderate/low issues. For auto-setup, 4 approaches identified with a clear recommendation.
