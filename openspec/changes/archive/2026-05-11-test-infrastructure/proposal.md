# Proposal: test-infrastructure

## Intent

Enable automated tests so we can verify changes don't break existing functionality. Currently `test_midi.lua` copies `midi.GetMidiNote` logic locally — it can't catch regressions in the real module. Five state stores and `progression.lua` have zero `reaper.*` dependencies but zero test coverage.

## Scope

### In Scope
- `tests/helpers.lua` — `check()`, assertion helpers, summary with exit code
- `tests/run.lua` — package.path setup, test discovery (`test_*.lua`), aggregate results, `os.exit(0/1)`
- Refactor `tests/test_midi.lua` — replace local `GetMidiNote`/`SCALES`/`CHORD_MODES` with `require("core.midi")` and `require("config")`
- `tests/test_stores.lua` — all 5 stores: Init, getter/setter round-trip, Consume lifecycle, edge cases
- `tests/test_progression.lua` — Add/Remove/Swap/Clear/GetLastFilled across empty→full states

### Out of Scope
- Mock infrastructure for `reaper.*` / `gfx.*` (deferred to future change)
- Tests for `midi.SendMidi`, `keyboard.*`, `sequencer.*`, `slots.*` (all require mocks)
- CI pipeline or test watcher

## Capabilities

### New
- **test-runner**: unified test execution with package.path, discovery, aggregation
- **store-tests**: state store Init + getter/setter validation
- **progression-tests**: progression CRUD + edge cases
- **midi-note-tests**: formalized spec for MIDI note calculation tests against real module

### Modified
- None — no existing spec files change

## Approach

Phase 1 (zero-mock) per exploration recommendation:

1. `helpers.lua` — standalone check/assert helpers, no deps
2. `run.lua` — derive `src/` path from own location via `debug.getinfo`, normalize Windows backslashes, scan `test_*.lua`, wrap each in `pcall`, aggregate pass/fail, own `os.exit()`
3. `test_midi.lua` — replace local tables with `require("config")`, replace local `GetMidiNote` with `require("core.midi").GetMidiNote`, replace `GetChordNotes` with per-offset `GetMidiNote` calls (real module doesn't export `GetChordNotes`)
4. `test_stores.lua` — per-store: Init(defaults) → each getter returns default → each setter round-trip → edge cases (nil, wrong types) → Consume lifecycle where applicable → Reset() for drag
5. `test_progression.lua` — empty state → Add → GetLastFilled → Remove → Swap → Clear → double-add → swap source=target

Module identity: stores need re-Init() between test groups (require returns singleton).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `tests/helpers.lua` | New | Test assertion utilities |
| `tests/run.lua` | New | Test runner entry point |
| `tests/test_midi.lua` | Modified | Refactored to test real module |
| `tests/test_stores.lua` | New | 5 state store test files |
| `tests/test_progression.lua` | New | Progression CRUD tests |

No `src/` files touched.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Module identity: require singleton across test groups | Med | Each test file is separate `require` — fine. Same-file groups need explicit re-Init |
| Exit code ownership: test_*.lua must NOT call os.exit | Low | run.lua wraps each file in pcall, owns os.exit |
| Windows path backslashes in debug.getinfo | Low | `gsub("\\", "/")` before building package.path |
| GetChordNotes doesn't exist in real module | Certain | Adapt chord tests to loop over config.CHORD_MODES offsets + per-offset GetMidiNote calls |

## Rollback Plan

Delete created files, restore `tests/test_midi.lua` from git.

## Dependencies

- Lua 5.4.6 at `C:\Users\Andrik\AppData\Local\Temp\lua54.exe` (not in PATH)

## Success Criteria

- [ ] `run.lua` exits 0 with all tests passing: existing midi tests (refactored) + store tests (5 stores) + progression tests
- [ ] `run.lua` exits 1 when a test deliberately fails (positive failure detection)
- [ ] `test_midi.lua` independently runnable still passes (backwards compat)
