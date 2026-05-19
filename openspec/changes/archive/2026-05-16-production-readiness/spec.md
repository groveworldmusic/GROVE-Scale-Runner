# Spec: Production Readiness Lockdown

## Change Overview
- **Name**: Production Readiness Lockdown
- **Summary**: Addresses 20 production-readiness issues (3 blockers, 10 high, 7 low/medium) to bring GROVE FL MIDI to production quality. Focuses on preference persistence reliability, keyboard hot path efficiency, GFX resource safety, and system robustness.

## Requirements

### Batch 1: Preference Persistence (P0 + P2)
- **User Requirement**: Preference changes must persist across restarts reliably, even if multiple changes occur in quick succession.
- **System Requirement**: Wire TickSaveDebounce into all 3 MainLoop branches; call persist.Save after each preference mutation (HandlePanel, inversion/subdivision in views, compact menu context handlers).
- **Acceptance Criteria**:
  - Given the script is running with debounced saving enabled
  - When user changes a preference 5 times within one frame
  - Then only one persist.Save() call occurs at the end of the frame, and all changes are saved atomically
  - And given the script is restarted
  - Then all preference changes are present

- **User Requirement**: Preset browser UI should be available only when LuaFileSystem is present.
- **System Requirement**: In main.lua or compact-init, check `_has_lfs` flag; if false, disable preset browser buttons and show tooltip explaining requirement.
- **Acceptance**: In environment without lfs, preset browser controls are visually disabled and hovering shows message "LuaFileSystem required for presets".

- **User Requirement**: Malformed or malicious preset files should not crash or execute arbitrary code.
- **System Requirement**: Preset loader must use sandboxed environment; only allow safe operations (table, math, string, table libs read-only). No io, os, dofile, loadstring from external. Use pcall to catch errors.
- **Acceptance**: Loading a preset containing `os.execute("rm -rf *")` fails gracefully with user message "Invalid preset file" and does not execute code.

- **User Requirement**: Preset file names must not allow directory traversal attacks.
- **System Requirement**: Sanitize preset name: strip `../`, `..`, any `\\` or `/` segments that ascend. Reject or truncate if sanitized name differs.
- **Acceptance**: Saving preset named `../../evil` results in either error or file named safely (e.g., `evil`), never writes outside preset directory.

- **User Requirement**: Missing preference keys in loaded state must be auto-created with defaults (upgrade safety).
- **System Requirement**: After `persist.Load(config.state)`, `preferences_store.SyncFromState()` must verify all preference keys exist; if missing, initialize with defaults and log warning.
- **Acceptance**: New preference added in code, user upgrades — program starts with default value for that preference, no crash.

### Batch 2: Keyboard Hot Path Optimization (P1)
- **User Requirement**: Keyboard response must be snappy; no perceivable input lag from redundant API calls.
- **System Requirement**: Move `JS_VKeys_GetState(0)` call before the pairs loop in `HandleKeyboard`. Cache `CheckAPI` (REAPER API availability) at module initialization. Reduce per-frame API calls from ~28 to ~2.
- **Acceptance**:
  - Given a fresh script start
  - When a key press is handled
  - Then `JS_VKeys_GetState(0)` is called exactly once per `HandleKeyboard` invocation (verified via debug counter or code inspection)
  - And `CheckAPI` result is computed once at module load, not every frame
  - And latency feels identical to previous version in manual testing

### Batch 3: GFX Safety & Resource Management (P3 + P4)
- **User Requirement**: Script should not crash when GFX initialization fails (e.g., LICE memory allocation failure).
- **System Requirement**: Replace all bare `gfx.init()` calls with `gfx_safe.SafeGfxInit()`. SafeGfxInit must catch errors, show user-friendly message, and attempt to continue with degraded UI.
- **Acceptance**: Simulate LICE allocation failure (mock or actual OOM); script shows error dialog but does not crash; main loop continues or exits gracefully.

- **User Requirement**: Mouse wheel scrolling must work consistently in all views without repeating scroll events.
- **System Requirement**: Unconditionally zero `gfx.mouse_wheel = 0` at end of every MainLoop frame, in all 3 branches (dock, standalone, compact).
- **Acceptance**: Scrolling in FULL view with wheel → page changes once per wheel tick, no repeats after one tick.

- **User Requirement**: Keyboard hot path should not read stale preference values.
- **System Requirement**: Migrate hot path from direct `config.state` reads to `preferences_store` getters (e.g., `preferences_store.GetOctave()`).
- **Acceptance**: Changing octave preference and pressing key yields correct MIDI note based on new value.

### Batch 4: System Robustness (Remaining Medium/Low)
- **User Requirement**: `setActiveNote` must not accept invalid note numbers.
- **System Requirement**: Add sanity check: if `note < 0` or `note > 127`, ignore and log warning.
- **Acceptance**: Calling `setActiveNote(-1)` does not crash; active_notes table unchanged.

- **User Requirement**: `draw_note` must handle missing note data fields gracefully.
- **System Requirement**: Before accessing `note.start_x` or `note.start_y`, verify fields exist; if missing, skip drawing and log warning.
- **Acceptance**: Corrupted note object with nil `start_x` does not crash draw loop; warning logged.

- **User Requirement**: Keyboard focus timing during drag operations must not cause lost key releases.
- **System Requirement**: Validate keyboard state capture timing; ensure that `gfx.getchar()` does not miss release events during drag. May require adjusting focus window or using REAPER's `GetKeyState` as backup.
- **Acceptance**: Drag with mouse while pressing/releasing keys — no stuck virtual key states observed.

- **User Requirement**: Sequencer sub-step calculations must handle progress values at boundary conditions (0.0, 1.0, >1.0).
- **System Requirement**: Add tests or guards so that `progress >= 1.0` properly advances measure and resets without skipping steps.
- **Acceptance**: Simulating progress = 0.9999999 vs 1.0000 triggers correct measure advancement.

## Non-Goals
- Architectural refactors, new features, UI redesigns
- LOW priority items (L1-L4) — e.g., piano.lua O(N·M) optimization (already fixed in other work), undo stack duplicates
- MIDI island velocity editor investigation
- Performance optimizations beyond the 28× API call reduction
- Preset format changes — backward compatibility must be maintained

## Dependencies
- Batch 1 must be applied before Batch 3 (persistence foundation first)
- Batch 2 independent; can be done in parallel with B1/B3
- Batch 3 depends on presence of `gfx_safe` module (already exists in src/ui/gfx-safe.lua)
- Batch 4 independent; can be done in parallel
- All batches require `preferences_store` to be properly imported and initialized in main.lua (P0 includes this)

## Open Questions (from Proposal)
- Should SafeGfxInit return a boolean success flag to allow caller to skip further GFX operations? (Proposed: yes, but maintain current call sites with slight refactor)
- Exact maintainer of `_has_lfs` flag — likely in `preset-store.lua` or `persist.lua`. Need to verify and wire UI accordingly.
- Migration of keyboard hot path: should we replace all `config.state` reads with getters, or only the hot path ones? Hot path only to minimize change surface.

## Error Handling Expectations
- All risky operations (LICE allocation, file I/O, load in sandbox) must use `pcall` and fall back to safe default or user message.
- Errors during preference save should not abort MainLoop; log warning and continue.
- Errors during preset load should not crash; show message "Failed to load preset" and keep current preset active.
- GFX init failures: SafeGfxInit shows modal error with `reaper.MB()` but allows script to continue (degraded mode) or clean exit depending on severity.

## Performance Considerations
- Zero new allocations per frame in hot paths; reuse temp tables (keyboard's `temp_ctx`, gfx.mouse_wheel zeroing is simple assignment).
- LICE cleanup (FreeBitmap/FreeFont) must not block main loop; these are called in CleanupAll only, which is fine.
- Sandbox `load` with environment has negligible overhead compared to file I/O cost.
- Debounced preference save reduces I/O from N per frame to 1 per frame (or less if no changes).

## Edge Cases Specific to This Change
- Preset file is empty or malformed JSON/table syntax → load fails, handled.
- LICE resource allocation fails (out of memory) → SafeGfxInit catches.
- GFX context init called while another context active (double init) → SafeGfxInit must detect and fail gracefully.
- `gfx.mouse_wheel` negative values (reaper returns positive/negative depending on direction) → zeroing still works, ensure logic respects sign before zero.
- `persist.Load()` returns partial state where some keys are missing → SyncFromState must supplement with defaults.
- Keyboard state cache becomes stale if REAPER API changes during long session — not expected; if it happens, restart required (acceptable).

## Verification Strategy

### Batch 1: Preference Persistence
- Static review: confirm `TickSaveDebounce()` is called in all 3 MainLoop branches (standalone, dock, compact).
- Manual: change preferences repeatedly in one frame, restart script, verify all saved.
- Manual: simulate missing `lfs` library (rename lua file temporarily), verify UI disables and tooltip appears.
- Manual: attempt to save preset named `../../evil` — verify sanitized name or error.
- Static review: check `preferences_store.SyncFromState` calls `Init` for missing keys.

### Batch 2: Keyboard Hot Path
- Static review: verify `JS_VKeys_GetState(0)` moved before pairs loop in `keyboard.lua`; verify `CheckAPI` cached at module top.
- Instrumentation (temporary counter): log calls to `JS_VKeys_GetState` per frame; confirm count drops from ~28 to ~1.
- Manual: key press latency test — play chords rapidly, ensure no perceived lag vs baseline.

### Batch 3: GFX Safety
- Static review: grep for `gfx.init(` and confirm all call sites use `gfx_safe.SafeGfxInit()`.
- Manual: simulate OOM (if possible) or mock failure; confirm SafeGfxInit shows error and does not crash.
- Manual: scroll wheel test in FULL view — ensure single scroll per tick, no repeat.
- Static review: verify keyboard hot path uses `preferences_store.Get*` getters, not direct state access.

### Batch 4: Robustness
- Static review: check `midi.lua` `setActiveNote` has range check; `piano-roll`/`piano.lua` draw functions check field existence.
- Manual: inject malformed note object with nil fields; verify no crash and warning logged.
- Manual: test keyboard drag sequence (press key, drag mouse, release key) — no stuck keys.
- Unit/static: review `sequencer.lua` progress boundary logic; add debug prints or tests to verify measure advancement at 0.999 vs 1.0.

### Regression Suite
- Run all existing tests in `tests/` (~497 assertions). No failures allowed.
- Manual smoke test: open script in REAPER, play/stop, open panels, change preferences, close and restart, verify state persists.
- Verify no new circular dependencies introduced (grep for require cycles).

## Implementation Notes
- Each batch should be an atomic commit for easy rollback.
- Use Engram to record decisions and learnings during implementation.
- Update `.llm/knowledge/decisions.md` and `.llm/knowledge/learnings.md` as needed.
- Respect the GFX dual-context pattern: both `main.lua` and `compact.lua` must zero `gfx.mouse_wheel`.
