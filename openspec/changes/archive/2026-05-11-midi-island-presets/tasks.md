# Tasks: Comportamiento de la isla MIDI + Sistema de Presets

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~73 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Schema + Capture + Materialization + Presets v2 | PR 1 | Single PR — under 100 lines, no chaining needed |

## Phase 1: Schema & Capture

- [ ] 1.1 Add `velocity=100, duration=4` fields to the entry table in `slots.lua` drop handler (line 152-158)

## Phase 2: Materialization

- [ ] 2.1 Modify `ProgressionToNotes()` in `island.lua` (line 176-201): per-entry velocity with fallback chain `entry.velocity` → `velocity` param → 100
- [ ] 2.2 Modify `ProgressionToNotes()` in `island.lua`: per-entry duration with fallback chain `entry.duration` → `beats_per_slot` param → 4

## Phase 3: Presets v2

- [ ] 3.1 Update `SavePreset()` in `preset-browser.lua`: write `version=2`, `progression` array, and context fields (`root_index`, `scale_index`, `octave`, `chord_mode_index`)
- [ ] 3.2 Update `LoadPreset()` in `preset-browser.lua`: detect `version` field — v2 restores notes + progression (via `seq_store.SetProgression()`) + context (via `config.state.*`); v1 loads notes-only backward compat
- [ ] 3.3 Add `RenamePreset()` in `preset-browser.lua`: `reaper.GetUserInputs()` for new name → `os.rename()` → `ScanDirectory()` rescan
- [ ] 3.4 Wire rename action into browser UI: add "Rename" button next to Save/Load, active only when a preset is selected, triggers `RenamePreset()` on click
