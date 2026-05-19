# Tasks: Test Infrastructure

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~250-350 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | exception-ok |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Foundation — Helpers + Runner

- [x] 1.1 Create `tests/helpers.lua` — `check()`, `assert_eq()`, `summary()` with pass/fail counters
- [x] 1.2 Create `tests/run.lua` — `debug.getinfo` path derivation, `package.path` setup, `dofile()` test discovery over `test_*.lua`, `os.exit` override/restore, aggregate summary and final exit code

## Phase 2: Refactor — Existing Test

- [x] 2.1 Refactor `tests/test_midi.lua` — replace local tables with `require("config")` and `require("core.midi")`, remove standalone `os.exit`, adapt chord tests to per-offset `midi.GetMidiNote` calls with `helpers.check`

## Phase 3: New Tests — Stores + Progression

- [x] 3.1 Create `tests/test_stores.lua` — test all 5 stores (compact, drag, sequencer, midi, ui): fresh Init per section, every getter/setter round-trip, Consume lifecycle (mouse_click, mouse_wheel_delta), edge cases (nil values, overwrites)
- [x] 3.2 Create `tests/test_progression.lua` — test Add/Remove/Swap (source≠target, source=target)/Clear/GetLastFilled, empty state, boundary conditions

## Phase 4: Verify

- [x] 4.1 Run `lua54.exe tests\run.lua` — confirm all tests pass (0 failures, exit code 0)
