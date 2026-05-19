## Proposal: Production Readiness for GROVE Scale Runner

### Intent

Resolve all CRITICAL and HIGH findings from the production readiness audit — preference persistence is broken (TickSaveDebounce never wired), keyboard hot path makes 28× redundant API calls per frame, and 4 UI components silently discard preference changes on restart. Make the script robust for real-world use.

### Scope

#### In Scope
- Wire TickSaveDebounce into MainLoop and import/Init preferences_store (C1, M4)
- Move JS_VKeys_GetState(0) before the pairs loop + cache CheckAPI result (C2, M2)
- Add persist.Save to HandlePanel, compact-menu, views.lua inversion/subdivision (H1-H4)
- Replace bare gfx.init() with SafeGfxInit in dock transport bar + ToggleIsland (H5)
- Unconditional gfx.mouse_wheel zero every frame (M3)
- Migrate keyboard hot path from config.state reads to preferences_store (M5)

#### Out of Scope
- Architectural refactors, new features, UI redesigns, LOW priority items (L1-L4)
- Performance optimizations beyond the redundant API calls
- MIDI island velocity editor investigation (unrelated)

### Capabilities

#### New Capabilities
None — this is a bugfix/robustness change.

#### Modified Capabilities
None — no spec-level behavior changes.

### Approach

Prioritized fix order:

**P0 — Wire TickSaveDebounce**: Import preferences_store in main.lua, call Init(config.state) + SyncFromState(config.state) after persist.Load, call TickSaveDebounce() in all 3 MainLoop branches. Single atomic commit.

**P1 — Fix 28× API calls**: Move JS_VKeys_GetState(0) call before the pairs loop, cache CheckAPI result at module init. Single commit.

**P2 — Plug 4 persistence gaps**: Add persist.Save() after each preference mutation in compact-init.lua HandlePanel, views.lua inversion/subdivision setters, compact-menu.lua context menu handlers. Single commit.

**P3 — SafeGfxInit**: Replace bare gfx.init() in views.lua:860 (dock transport bar) and midi.lua ToggleIsland with gfx_safe.SafeGfxInit(). Single commit.

**P4 — MEDIUM items**: Unconditional gfx.mouse_wheel = 0 in MainLoop; migrate keyboard hot path to use preferences_store getters. Single commit.

### Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| src/main.lua | Modified | Import preferences_store, Init+SyncFromState, TickSaveDebounce in all 3 loops |
| src/core/keyboard.lua | Modified | Cache JS_VKeys_GetState, cache CheckAPI, read from preferences_store |
| src/ui/views.lua | Modified | persist.Save for inversion/subdivision; SafeGfxInit for dock bar |
| src/ui/compact-init.lua | Modified | persist.Save after HandlePanel preference changes |
| src/ui/compact-menu.lua | Modified | persist.Save after context menu preference changes |
| src/core/midi.lua | Modified | SafeGfxInit in ToggleIsland |

### Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Keyboard/MIDI regression | Low | Existing tests (~497 assertions) + static review of each change |
| Preference save thrashing | Low | TickSaveDebounce already designed with per-frame flush; just needs wiring |
| GFX init crash in edge case | Low | SafeGfxInit handled; backed by existing gfx-safe type and error dialog |

### Rollback Plan

Each fix is an atomic commit. Full rollback via `git revert <merge-base>..HEAD` on the production-readiness branch. Atomic design means individual reverts are safe.

### Dependencies

None. All fixes are self-contained within the codebase.

### Success Criteria

- [ ] TickSaveDebounce confirmed called in all 3 MainLoop branches via code review
- [ ] JS_VKeys_GetState called exactly once per HandleKeyboard invocation
- [ ] All 4 HIGH persistence gaps resolved: preference changes in compact panel, compact menu, and views survive restart
- [ ] SafeGfxInit used in ALL gfx.init() call sites (confirm via grep)
- [ ] All existing tests pass with zero regressions
- [ ] No new circular dependencies introduced
