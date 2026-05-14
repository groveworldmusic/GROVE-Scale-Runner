# Proposal: Project Refactor — Phase 1

## Intent

Reduce coupling and file sizes in the Scale Runner LUA codebase by extracting 4 self-contained concerns into dedicated files. No behavioral changes — pure structural refactor.

## Scope

### In Scope
- Extract coordinate system from `views.lua` → `ui/layout.lua` (SetScale, UX, UY, US, canvas constants)
- Extract domain logic from `views.lua` (ToggleMIDIIsland, channel change, volume slider)
- Extract keyboard handling from `main.lua` → `core/keyboard.lua`
- Move MIDI state fields from `config.state` → `core/midi.lua`

### Out of Scope
- `components.lua` decomposition (Phase 2)
- `compact.lua` decomposition (Phase 2)
- Global state store (Phase 3)
- Any behavioral changes or new features

## Capabilities

### New Capabilities
None — pure refactor, no new features introduced.

### Modified Capabilities
None — spec-level behavior unchanged. All extractions are internal moves.

## Approach

4 sequential extractions, each as a separate commit:

1. **Extract layout** — `SetScale/UX/UY/US/CANVAS_W/CANVAS_H` → `ui/layout.lua`. Zero deps, pure constants.
2. **Extract keyboard** — `HandleKeyboard/InterceptMappedKeys/IsPluginOrScriptFocused/CheckFocus` → `core/keyboard.lua`. Update `main.lua` imports.
3. **Move MIDI state** — `midi_channel, midi_island_expanded, midi_island_toggled` from `config.state` → `core/midi.lua`. Update all references.
4. **Move ToggleMIDIIsland** — from `views.lua` to `core/midi.lua`. Update imports in `components.lua`, `compact.lua`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/views.lua` | Modified | Removed layout constants + MIDI toggle/channel/volume logic |
| `src/main.lua` | Modified | Removed keyboard functions, delegated to core/keyboard |
| `src/config.lua` | Modified | Removed 3 MIDI state fields |
| `src/core/midi.lua` | Modified | Absorbed MIDI state fields + ToggleMIDIIsland |
| `src/ui/layout.lua` | **New** | SetScale, UX, UY, US, canvas constants |
| `src/core/keyboard.lua` | **New** | All keyboard handling from main.lua |
| `src/ui/components.lua` | Possibly modified | If volume slider drag lives here, update import path |
| `src/ui/compact.lua` | Possibly modified | Update ToggleMIDIIsland import path |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Missed import path | Medium | `grep` for every UX/UY/US/ToggleMIDIIsland ref before moving |
| Circular dependency | Low | Layout = zero deps; keyboard deps are stable (ui, core) |
| Missing an export | Low | Run script after each extraction commit |

## Rollback Plan

Each extraction is a separate commit. If any breaks, `git revert <commit>` undoes just that slice. All work on a feature branch — `main` stays clean until final merge.

## Dependencies

None.

## Success Criteria

- [ ] All UX/UY/US calls work via `ui/layout.lua` import
- [ ] Keyboard handling works via `core/keyboard.lua`
- [ ] MIDI toggle + channel selection work as before
- [ ] Script starts and runs without errors in both expanded + collapsed modes
