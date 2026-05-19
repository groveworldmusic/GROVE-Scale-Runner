# Proposal: Que ves incompleto

## Intent

Close systemic gaps found across documentation, state architecture, a disabled feature, and testing. The project is mature but has accumulated documentation drift, dual state access paths, and half-finished features — this change tightens those loose ends without adding new capability.

## Scope

### In Scope
- **Sync AGENTS.md with actual codebase** — update all 6 AGENTS.md files (root, `src/`, `src/core/`, `src/ui/`, `src/state/`, `tests/`) to reflect actual files, LOC, counts, and dependency edges
- **Eliminate dual state access** — migrate remaining `config.state.*` runtime reads to `preferences_store` uniformly; remove the `local c = ctx or config.state` fallback in `midi.TriggerChord`
- **Complete velocity editor** — investigate why `ve_h = 0` was set (midi-island.lua:343), either fix and enable, or remove dead code
- **Add LICENSE file** — MIT, as referenced by SPDX headers on every source file
- **Integrate barrel-backward-compat test** — add to `test_names` in `tests/run.lua`

### Out of Scope
- Split midi-island monolith (architectural refactor, separate change)
- Settings UI panel (requires full feature design)
- MIDI export / progression save-load / arpeggiator / multi-track / preset browser / keyboard overlay (new features)
- TriggerChord parameter redesign (risky without deeper consumer analysis)
- UI/integration test suite (scope too large, needs dedicated testing change)

## Capabilities

### New Capabilities
- `velocity-editor`: Activate the disabled velocity bar display and drag-to-edit interaction (spec exists, code exists, just needs enablement)

### Modified Capabilities
- None — all changes are internal fixes or documentation corrections

## Approach

Four workstreams in parallel where safe:

1. **Docs**: Walk each AGENTS.md, cross-reference against actual `src/` tree, update file lists, LOC counts, API docs, and dependency map
2. **State**: Audit all callers of `config.state.*`, replace with `preferences_store.*` equivalents, remove fallback in `midi.TriggerChord`
3. **Velocity**: Check `ve_h = 0` commit history / git blame to find disable reason, fix or remove — then wire `velocity.lua` into midi-island's render pipeline
4. **Legal + Test**: Add MIT `LICENSE` file; append barrel-backward-compat to test runner list

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `AGENTS.md` (root, src/) | Modified | 6 files, sync content |
| `src/core/midi.lua` | Modified | Remove config.state fallback |
| `src/state/preferences.lua` | Verified | Ensure complete coverage |
| `src/ui/midi-island.lua` | Modified | Wire velocity editor |
| `src/ui/velocity.lua` | Verified | Ensure render-ready |
| `tests/run.lua` | Modified | Add barrel test |
| Root `LICENSE` | New | MIT text |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Velocity disabled by unknown/unfixable bug | Medium | Investigate first; if blocked, remove dead code cleanly |
| Dual state migration misses a path | Low | grep `config.state\.` in runtime code; ~10 remains |

## Rollback Plan

If velocity activation breaks: set `ve_h = 0` back. If state migration breaks consumers: revert TriggerChord fallback. All changes are localized and independently revertable.

## Dependencies

- None. All changes are internal and require no external resources.

## Success Criteria

- [ ] Root AGENTS.md accurately lists all 50+ source files, dependency edges, and test count
- [ ] Zero runtime reads of `config.state.*` in non-config source files (excluding `config.lua` init)
- [ ] Velocity editor renders and responds to click-drag in the MIDI island
- [ ] `LICENSE` file present at project root
- [ ] `barrel-backward-compat.lua` executes as part of test suite
