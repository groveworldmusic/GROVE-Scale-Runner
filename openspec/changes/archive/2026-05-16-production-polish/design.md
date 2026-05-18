# Design: production-polish

## Technical Approach

The goal is to address performance and documentation gaps.

1.  **MIDI Optimization**: We will implement a reusable `temp_ctx` table in `src/core/midi.lua`. This table will be used by `midi.TriggerChord` to avoid the allocation of a new context table on every call, which is critical since `TriggerChord` is called frequently in the sequencer loop.
2.  **Architecture Update**: We will update `.llm/knowledge/architecture.md` to include a new "Performance & Optimization" section that documents this and other similar patterns, and ensure the current directory structure and dependencies are correctly reflected.

## Architecture Decisions

### Decision: Reusable `temp_ctx` in `midi.lua`

**Choice**: Implement a module-level `local temp_ctx = {}` in `src/core/midi.lua`.

**Alternatives considered**:
- **Allocate on call**: (Current implementation) Increases GC pressure in the hot path.
- **Pass `temp_ctx` from caller**: Requires all callers (like `keyboard.lua`) to manage a context table, increasing complexity elsewhere.

**Rationale**: Centralizing the optimization within `midi.lua` provides the best balance between performance gains and maintainability. Since `midi.lua` is the primary consumer of chord logic, it is the most effective place to manage this lifecycle.

### Decision: Performance Documentation Section

**Choice**: Add a "Performance & Optimization" section to `.llm/knowledge/architecture.md`.

**Alternatives considered**:
- **No documentation update**: Risks future developers breaking the optimization by re-introducing allocations.

**Rationale**: Documenting the "Why" behind the `temp_ctx` pattern prevents regression and establishes a standard for future performance-critical modules.

## Data Flow

For `midi.TriggerChord`:
```
Sequencer Loop ──→ midi.TriggerChord(degree, on) ──→ (if ctx is nil) ──→ Populate temp_ctx from prefs ──→ midi.SendMidi
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/core/midi.lua` | Modify | Add `local temp_ctx = {}` and refactor `TriggerChord` to use it. |
| `.llm/knowledge/architecture.md` | Modify | Add "Performance & Optimization" section and verify structure. |

## Interfaces / Contracts

`midi.TriggerChord` signature remains unchanged:
```lua
-- midi.TriggerChord(degree, on, ctx?, velocity?, inversion_index?) → number[]
```
When `ctx` is provided, it is used as the source of truth. When `ctx` is `nil`, `temp_ctx` is populated with values from `preferences_store` and used.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `TriggerChord` logic with/without `ctx` | Verify that chords are correctly triggered with various scale, root, and octave settings. |
| Integration | Sequencer loop stability | Verify that the sequencer continues to run smoothly and MIDI notes are sent correctly. |

## Migration / Rollout

No migration required.

## Open Questions

- None
