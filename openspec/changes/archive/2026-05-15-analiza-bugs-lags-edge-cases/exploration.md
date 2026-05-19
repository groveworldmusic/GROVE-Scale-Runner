## Exploration: Codebase Bug/Lag/Edge-Case Analysis

### Current State

The GROVE FL MIDI project is a mature REAPER GFX-based MIDI controller (QWERTY-to-MIDI) with ~38 source files and ~5,100 LOC. It has undergone significant refactoring (phases 1-3d): state extraction from `config.state` into 6+ domain stores, introduction of barrel modules, lazy require patterns, and event-bus patterns for mouse events. The code quality is generally high with good defensive patterns (`api_guard.ClampIndex`, `gfx_safe.SafeGfxInit`, ref-counted active notes). However, several performance issues, edge-case gaps, and quality concerns remain.

### Issues Found

#### Category 1: Performance / Lag

- **`src/core/keyboard.lua` (line 23) — SEVERITY: HIGH**
  `reaper.JS_VKeys_GetState(0)` is called INSIDE the `for k_code, state in pairs(...)` loop (line 22-47). This means the API is invoked **28 times per frame** instead of once. The return value is frame-constant as it captures the entire keyboard state. **Fix**: call once before the loop, cache to local variable.

- **`src/ui/pads.lua` (line 32) — SEVERITY: MEDIUM**
  `for _, state in pairs(midi_store.GetKeyStates()) do` iterates all 28 key states every frame, for EACH of the 7 pads. This is O(7·28) = 196 iterations per frame just to check if any key matches the current pad's degree. **Fix**: pre-compute a `degree→active` lookup table once per frame, or pass the active-degree info as a parameter.

- **`src/ui/piano.lua` (lines 73-76) — SEVERITY: LOW**
  `active_mod12` table is re-allocated every frame regardless of whether active notes changed. While the O(1) lookup is correct (Issue 18 fixed), the table allocation and `pairs()` scan of active_notes happens on every draw. **Fix**: cache with a revision counter (e.g., track `active_notes_revision` and rebuild only on change).

- **`src/ui/dropdown.lua` (lines 21-38) — SEVERITY: LOW**
  The `GetFitText` inner function is defined as a **closure** on every dropdown draw call. This creates a new function object each frame, contributing to GC pressure at 60fps. **Fix**: hoist to module-level or inline the logic without closure allocation.

- **`src/core/midi.lua` (line 86-107) — SEVERITY: LOW**
  `TriggerChord` allocates a new `notes = {}` table and performs `table.insert` for each chord offset on every chord trigger. In normal use this is fine (not per-frame), but rapid key presses (e.g., glissando) could cause allocation bursts. **Fix**: pre-allocate with `local notes = {}; for i = 1, #offsets do notes[i] = ... end` to avoid dynamic resizing.

- **`src/ui/slots.lua` (lines 70-95) — SEVERITY: LOW**
  Subdivision dots loop calls `gfx.circle` and `gfx.measurestr` for each dot on every frame for every rendered slot. Accumulates across 4 slots. **Fix**: only compute dot positions when slot or subdivision changes (add revision tracking).

#### Category 2: Bugs

- **`src/ui/slots.lua` (lines 186-190) — SEVERITY: MEDIUM**
  Click-to-play on a slot fires `TriggerChord(degree, true)` followed immediately by `TriggerChord(degree, false)` in the same frame. The MIDI note-on and note-off are sent within microseconds of each other. REAPER may batch-process these, resulting in a **zero-duration note** that never actually produces sound on most VSTs. **Fix**: use a short deferred note-off via timer (e.g., set a flag, send note-off after N frames).

- **`src/ui/pads.lua` (line 32) — SEVERITY: LOW**
  The `pairs()` iteration over `midi_store.GetKeyStates()` works because it returns the **mutable reference** — but the state/AGENTS.md explicitly warns against mutating it directly. The pads code only reads `state.is_pressed` and `state.code`, but the pattern is fragile. If any code later adds `__pairs` metamethods or wraps the table, this could break silently.

- **`src/core/midi.lua` (line 97-101) — SEVERITY: LOW**
  `InvertChord` always allocates a new result table via `local result = {}`. The function comment says "Pure function" — this is correct behavior, but callers should be aware that every inversion triggers an allocation. In the hot path (TriggerChord called per key press), this is fine but worth noting.

- **`src/state/preferences.lua` (lines 55-61) — SEVERITY: LOW**
  Every setter calls `persist.Save()` **synchronously** via `reaper.SetExtState`. For rapid changes (e.g., scrolling through scales with mouse wheel), this could cause REAPER ExtState write contention. **Fix**: debounce persistence or batch writes.

#### Category 3: Edge Cases

- **`src/core/keyboard.lua` (line 23) — SEVERITY: MEDIUM**
  `JS_VKeys_GetState(0)` passes a literal `0`. The JS_ReaScriptAPI docs expect a **pointer-sized integer** for the state parameter. Using `0` means "get the state of the entire keyboard" — this works but the parameter should be a state buffer variable. A potential future REAPER API change could break this usage pattern. **Fix**: pass a proper state buffer variable.

- **`src/core/sequencer.lua` (lines 102-104) — SEVERITY: LOW**
  The catch-up loop for skipped measures works correctly but silently skips slots. If the user's frame rate drops significantly (e.g., from 60fps to 10fps due to CPU spike), multiple measures worth of slots never play. This is documented in comments but could surprise users. **Fix**: no change needed — this is an intentional design decision documented in code.

- **`src/core/midi.lua` (line 20) — SEVERITY: LOW**
  `midi_channel = 1` is hardcoded with no UI control to change it. Users who need a specific MIDI channel (e.g., channel 2 for layered instruments) cannot configure this. **Fix**: expose in preferences or add a store setter.

- **`src/main.lua` (lines 310-316) — SEVERITY: LOW**
  The Escape/Close handler calls `CleanupAll()` and then `SafeGfxQuit()`, while `reaper.atexit` also calls `CleanupAll()`. The `did_cleanup` flag prevents double cleanup, but the order matters: manual cleanup calls `SafeGfxQuit` at the end, while atexit calls it implicitly via `gfx.quit` on window close. This is guarded but fragile. **Fix**: no immediate action — guard works correctly.

- **`src/config.lua` (line 123-125) — SEVERITY: LOW**
  Key states initialization happens at module load via config.lua, BEFORE stores are initialized. This means `config.state.key_states` is the canonical copy and stores point to it by reference. If stores ever replace their key_states table (via SetKeyState with a new table), the reference to config.state breaks. Currently no code does this, but it's a potential future bug.

#### Category 4: Code Quality

- **`src/config.lua` — SEVERITY: MEDIUM**
  `config.state` still contains ~28 keys, many of which have been migrated to stores. The `state.persist` system reads/writes `config.state` directly, and `preferences_store.SyncFromState` copies from `config.state` into the store. The dual-source pattern (config.state defaults + store defaults) is fragile — if they diverge, unexpected behavior results.

- **Source-wide — SEVERITY: LOW**
  ~22 remaining `config.state.*` references in source code (mostly `view_offset_x/y`, plus test files). These should be migrated to dedicated stores (e.g., a `positioning` store for offset values, or the existing `preferences_store`).

- **`src/ui/views.lua` (line 242) — SEVERITY: LOW**
  Issue 9 comment about octave dropdown rendering is still present but the dropdown works correctly. The comment may be stale — verify if the fix was applied as part of a larger refactor.

- **`src/ui/views.lua` (line 684) — SEVERITY: LOW**
  Issue 6 still open: U+25C4 glyph for undock button may not render on all systems. The glyph `◄` is used but support varies by font rendering system on Windows.

- **Source-wide — SEVERITY: LOW**
  Inconsistent function definition style: some modules use `function m.func()` (buttons.lua, pads.lua, piano.lua, slots.lua) while others use `function m.func` (midi.lua, sequencer.lua, keyboard.lua). Both are valid Lua, but consistency improves maintainability.

- **`src/ui/layout.lua` — SEVERITY: LOW**
  Module-level `_S, _OX, _OY` variables persist between frames. If `DrawFullView` is called without a preceding `SetScale`, these contain stale values. There's no guard or validation.

- **`src/core/api-guard.lua` (line 43-54) — SEVERITY: LOW**
  `ClampIndex` writes to `reaper.ShowConsoleMsg` every time a value is clamped. During normal operation (e.g., scrolling past boundary), this fills the console with messages. Could be noisy for users.

### Known Issues Status

| Issue | Status | Notes |
|-------|--------|-------|
| #5 | **FIXED** | Release pad-held notes only when drag starts — pads.lua lines 70-75 |
| #6 | **STILL OPEN** | U+25C4 glyph support for undock button — views.lua line 684 |
| #7 | **FIXED** | Transport window find — SWS fallback chain — compact-init.lua lines 33-47 |
| #8 | **FIXED** | DecrementPageOverrideTimer in ALL modes — views.lua lines 472-475, main.lua line 229 |
| #9 | **STILL OPEN / VERIFY** | Octave dropdown rendering — views.lua line 242. The comment references the issue but testing needed |
| #10 | **FIXED** | Invalidate auto-position cache on transport resize — positioning.lua lines 132-134 |
| #12 | **FIXED** | Reusable temp_ctx table for key press handling — keyboard.lua line 16 |
| #13 | **FIXED** | Cached scale note tables — piano.lua lines 43-47, 64-68 |
| #18 | **FIXED** | O(N·M) inner loop → O(1) via pre-computed pitch-class set — piano.lua lines 72-76 |
| #19 | **FIXED** | Cache GetLastFilled() once per tick — sequencer.lua line 84 |
| #21 | **FIXED** | Velocity humanization (85 + math.random(30)) — keyboard.lua line 31 |
| #22 | **FIXED** | Stuck note on play/stop toggle — all toggle sites call sequencer.Stop() before SetIsPlaying(false) |

### Approaches

1. **Phased Bug-Fix Approach** — fix issues by priority/severity
   - **Pros**: Minimal risk per change, well-scoped PRs, easy to review
   - **Cons**: Iterative, takes more total time, some low-severity issues may never be addressed
   - **Effort**: Medium (3-5 focused batches)

2. **Comprehensive Sweep** — address everything systematically
   - **Pros**: All issues fixed at once, single refactor context, clear diff
   - **Cons**: Large diff (~300-500 lines), harder to review, higher risk of regressions
   - **Effort**: High (6-10 focused change sets)

### Recommendation

**Approach 1: Phased Bug-Fix Approach**. Start with the HIGH-severity performance bug (JS_VKeys_GetState called 28x/frame) and the MEDIUM bug (slots.lua immediate note-off), then address edge cases and code quality issues in subsequent phases. This keeps each PR focused and reviewable within the 400-line budget.

### Risks

- **keyboard.lua refactor**: Moving `JS_VKeys_GetState` outside the loop is safe (frame-constant data) but must not change behavior for concurrent triggers
- **slots.lua deferred note-off**: Requires careful timer management to avoid stuck notes or double-triggers
- **config.state migration**: Changing from dual-source (config.state + store defaults) to single-source requires coordination with `persist.lua` and `SyncFromState`
- **JS API changes**: REAPER API version differences (pre-7 vs post-7) could affect `JS_VKeys_GetState` behavior

### Ready for Proposal

Yes
