# Tasks: Production Polish

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | < 50 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Implement MIDI optimization and update docs | PR 1 | Atomic change for production readiness |

## Phase 1: Core Implementation

- [x] 1.1 Implement `temp_ctx` in `src/core/midi.lua` to reduce allocations in `TriggerChord`

## Phase 2: Verification

- [x] 2.1 Verify `midi.lua` optimization (via manual inspection or running existing tests)

## Phase 3: Documentation

- [x] 3.1 Update `.llm/knowledge/architecture.md` to reflect the latest architectural state and add Performance & Optimization section
- [x] 3.2 Verify `architecture.md` update
