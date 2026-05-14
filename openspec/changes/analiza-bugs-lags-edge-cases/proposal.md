# Proposal: Codebase Bug/Lag/Edge-Case Analysis & Fix

## Intent

Systematically fix every bug, performance issue, edge case, and code quality concern found during exploration. The project is mature (~5,100 LOC, 38 files, 6 state stores) but has accumulated a HIGH-severity perf bug (`JS_VKeys_GetState` called 28x/frame), a MEDIUM-severity bug (zero-duration notes from click-to-play), plus 12+ lower-severity items and 2 open known issues.

## Scope

### In Scope
- All performance items (keyboard.lua, pads.lua, piano.lua, dropdown.lua, midi.lua, slots.lua)
- All bug items (slots.lua, pads.lua, preferences.lua)
- All edge cases (keyboard.lua literal 0, midi.lua channel hardcoded, config.lua init ordering)
- All code quality items (config.state remnant ~28 keys, ~22 stale refs, layout.lua guards, api-guard.lua clamp noise)
- Known issues #6 (U+25C4 glyph) and #9 (octave dropdown rendering)
- Affects: main window > compact panel (most changes in core/ui modules shared by both)

### Out of Scope
- New features (new UI panels, MIDI modes, sequencer behaviors)
- Architectural rewrites (module restructuring, store redesign)
- UI redesign (theme, layout, component overhaul)
- Test infrastructure (no Lua test runner available)

## Capabilities

### New Capabilities
None — this is a bug-fix / quality change, no new spec-level capabilities introduced.

### Modified Capabilities
None — no existing capability changes at the spec level. All fixes are implementation-only.

## Approach

**Phased bug-fix per exploration recommendation.** Each phase is a focused, reversible PR via feature-branch-chain.

| Phase | Focus | Targets | Lines |
|-------|-------|---------|-------|
| 1 | HIGH perf + MEDIUM bug | `keyboard.lua` cache JS_VKeys_GetState, `slots.lua` deferred note-off | ~80 |
| 2 | MEDIUM remaining | `pads.lua` O(7·28) → pre-computed lookup, `keyboard.lua` literal 0, `preferences.lua` debounce | ~60 |
| 3 | LOW items | `piano.lua` revision cache, `dropdown.lua` hoist closure, `midi.lua` pre-allocate + channel config, `slots.lua` dots cache, `layout.lua` stale guard, `api-guard.lua` silent clamp | ~100 |
| 4 | Known issues | #6 U+25C4 glyph support (views.lua), #9 octave dropdown rendering (testing) | ~40 |
| 5 | Migration | ~28 config.state remnant keys → stores, ~22 stale refs cleanup | ~120 |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/core/keyboard.lua` | Modified | Cache JS_VKeys_GetState outside loop; fix literal 0 → state buffer var |
| `src/ui/slots.lua` | Modified | Deferred note-off timer for click-to-play |
| `src/ui/pads.lua` | Modified | Pre-compute degree→active lookup; pairs()→ipairs() |
| `src/ui/piano.lua` | Modified | active_mod12 cache with revision counter |
| `src/ui/dropdown.lua` | Modified | Hoist GetFitText closure to module level |
| `src/core/midi.lua` | Modified | Pre-allocate chord array slots; configurable midi_channel |
| `src/state/preferences.lua` | Modified | Debounce persist.Save on rapid scroll |
| `src/config.lua` | Modified | Init ordering guard; ~28 key cleanup |
| `src/ui/layout.lua` | Modified | Stale module-level variable guard |
| `src/core/api-guard.lua` | Modified | Silent clamp (no ShowConsoleMsg on boundary) |
| `src/ui/views.lua` | Modified | Issue #6 U+25C4 glyph support |
| Source-wide (~22 refs) | Modified | config.state.* → store migration |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `keyboard.lua` refactor breaks concurrent key triggers | Low | Cache is frame-constant — same value, called once. Verify pairs iteration unchanged. |
| `slots.lua` deferred note-off timer conflicts with other timers | Low | Use existing MainLoop frame counter; no new reaper.defer chains. |
| `config.state` migration breaks store Init() ordering | Med | Follow strict init order per AGENTS.md. Phase 5 is last and revertible. |
| Preferences debounce drops writes during rapid scroll | Low | Debounce by frame counter (60fps → ~16ms). Acceptable for persist. |

## Rollback Plan

Each phase is an independent PR in a feature-branch chain. Any phase can be reverted individually via `git revert <phase-pr-merge>`. The chain strategy means later phases target the previous phase's branch — rolling back an earlier phase cascades but each PR diff is self-contained.

## Dependencies

None. All fixes are self-contained within the existing codebase.

## Success Criteria

- [ ] `JS_VKeys_GetState` called exactly once per frame (Phase 1)
- [ ] No zero-duration MIDI notes from click-to-play (Phase 1)
- [ ] `pads.lua` O(196) → O(7+28) iterations per frame (Phase 2)
- [ ] All 12 exploration issues resolved (Phases 1-3)
- [ ] Known issues #6 and #9 closed (Phase 4)
- [ ] Zero `config.state.*` references remaining outside config.lua (Phase 5)
- [ ] No regressions in keyboard input, slot interaction, or persist behavior
