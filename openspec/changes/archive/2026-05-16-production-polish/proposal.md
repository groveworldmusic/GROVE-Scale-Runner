# Proposal: Production Polish

## Intent

Finalize the project for production readiness by addressing identified performance and documentation gaps. Specifically, reduce GC pressure in high-frequency MIDI triggers and ensure technical documentation accurately reflects the current architecture.

## Scope

### In Scope
- Implement reusable `temp_ctx` in `src/core/midi.lua` for `TriggerChord` to minimize table allocations.
- Audit and update `.llm/knowledge/architecture.md` with current module structure and dependency maps.

### Out of Scope
- Any new functional features.
- Changes to existing UI/UX behavior.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- None

## Approach

- **Optimization**: In `src/core/midi.lua`, declare a module-level `local temp_ctx = {}`. Within `midi.TriggerChord`, populate this table with necessary context instead of creating new tables every call.
- **Documentation**: Review `.llm/knowledge/architecture.md` and compare against `src/AGENTS.md` and the actual dependency graph to correct any outdated information.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/core/midi.lua` | Modified | Implementation of `temp_ctx` in `TriggerChord`. |
| `.llm/knowledge/architecture.md` | Modified | Update architectural documentation. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `temp_ctx` state leakage | Low | Ensure all fields are reset or overwritten in every call. |
| Documentation mismatch | Low | Verify against the codebase after updates. |

## Rollback Plan

- Revert changes to `src/core/midi.lua` using Git.
- Revert changes to `.llm/knowledge/architecture.md` using Git.

## Dependencies

- None

## Success Criteria

- [ ] `TriggerChord` calls in `src/core/midi.lua` no longer allocate new tables for context.
- [ ] `.llm/knowledge/architecture.md` accurately describes the current project structure and dependencies.
