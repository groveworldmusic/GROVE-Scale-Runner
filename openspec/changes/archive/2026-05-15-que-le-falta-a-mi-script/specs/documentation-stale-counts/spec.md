# Spec: Documentation Stale Counts

## Description
Multiple AGENTS.md files contain incorrect LOC counts and stale configuration.state reference counts.

## Requirements
1. Root AGENTS.md: config.state refs count updated from "~1" to actual count (~138)
2. Root AGENTS.md: views.lua LOC updated from 654 to 867
3. src/AGENTS.md: config.state remnants count updated
4. src/ui/AGENTS.md: island.lua LOC updated from 136 to 567
5. src/ui/AGENTS.md: interaction.lua LOC updated from 795 to 1051
6. src/state/AGENTS.md: island.lua LOC updated from 136 to 566

## Scenarios
- **Happy path**: All LOC and ref counts match actual source files
- **Edge case**: Some counts were already correct — no unnecessary changes

## Files Affected
- `AGENTS.md` (root): ~4 lines changed
- `src/AGENTS.md`: ~2 lines changed
- `src/ui/AGENTS.md`: ~6 lines changed
- `src/state/AGENTS.md`: ~2 lines changed

## Estimated LOC
~30 lines changed across 4 files
