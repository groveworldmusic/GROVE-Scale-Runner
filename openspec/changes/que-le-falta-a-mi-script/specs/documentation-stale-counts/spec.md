# Delta for Documentation Stale Counts

Doc fix: update AGENTS.md files with correct line counts, module counts, and config.state reference counts that have drifted since last update.

## ADDED Requirements

### Requirement: Update all documented LOC counts to match source reality

The system MUST update every file count in AGENTS.md files where the documented LOC differs from the actual source file line count by more than 5 lines.

Affected updates:

| File | Doc LOC | Actual LOC | Fix |
|------|---------|------------|-----|
| Root `AGENTS.md` "Referencias a config.state.* runtime" | ~1 | ~139 (12+ files) | Set to actual count |
| `src/ui/AGENTS.md` views.lua | 654 | 864 | Set to 864 |
| `src/ui/AGENTS.md` midi-island.lua | 132 | 205 | Set to 205 |
| `src/ui/AGENTS.md` interaction.lua | 795 | 1175 | Set to 1175 |
| `src/ui/AGENTS.md` "34 archivos fuente, ~6,342 LOC total" | ~6,342 | Recalculate based on actual LOC | Set to actual |
| `src/state/AGENTS.md` island.lua | 136 | 566 | Set to 566 |
| `src/state/AGENTS.md` preferences.lua | 81 | 77 | Set to 77 |
| `src/core/AGENTS.md` keyboard.lua | 105 | 110 | Set to 110 |
| `src/core/AGENTS.md` midi.lua | 232 | 236 | Set to 236 |
| `src/core/AGENTS.md` sequencer.lua | 131 | Verify | Set to actual |

#### Scenario: Developer reads AGENTS.md — counts match reality

- GIVEN a developer opens root `AGENTS.md` to understand project metrics
- WHEN they read the "Referencias a config.state.* runtime" line
- THEN the count MUST read "~139" (not "~1")
- AND all LOC values in File Map tables MUST match actual source line counts

#### Scenario: Already-correct counts — no unnecessary changes

- GIVEN `core/AGENTS.md` correctly lists `snap.lua` as 26 LOC
- WHEN the documentation update runs
- THEN correct values MUST NOT be changed

## MODIFIED Requirements

None — no existing spec for this domain.

## REMOVED Requirements

None.
