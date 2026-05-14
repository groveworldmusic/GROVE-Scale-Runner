# Proposal: Que le falta a mis script ?

## Intent

Full codebase audit: identify every missing piece, bug, debt, and feature gap in GROVE FL MIDI (~8,800 LOC, 53 src). Group findings into actionable sprints so the user decides what to tackle.

## Scope

| In | Out |
|----|-----|
| 17 findings organized into 5 workstreams | Implementation details (spec/design/tasks) |
| Priority ranking with dependencies | REAPER API research or 3P integrations |
| Recommendation for first sprint | Rewrite of existing working features |

## Capabilities

### New Capabilities
None — this proposal organizes existing work. Individual sprints will define new capabilities.

### Modified Capabilities
None — no spec-level changes defined until a sprint is selected.

## Approach

### Workstreams

| # | Sprint | Items | Effort | Depends |
|---|--------|-------|--------|---------|
| 0 | **Critical Bugs** | 4 bugs (config.state flood, JS_VKeys 28x/frame, pref_store desync, preset_browser Init/frame) | ~40 LOC | None |
| 1 | **Store Migration** | Complete config.state → preferences_store (~139 refs in 12+ files) | ~200 LOC | Sprint 0 |
| 2 | **Monolith Extraction** | interaction.lua (1051 LOC), views.lua (801 LOC) → submodules | ~400 LOC | Sprint 1 |
| 3 | **Feature Gaps** | Vel humanization (pads), MIDI channel, chord modes, MIDI CC, sustain | ~300 LOC | Sprints 1-2 |
| 4 | **Polish** | SPDX headers (49 files), PITCH_ROW_H hack, AGENTS.md stale counts | ~50 LOC | None |

### Sprint 0 — Critical Bugs (do FIRST)

1. **config.state flood**: ~139 refs in 12+ files. views.lua alone has ~51. root AGENTS.md says "~1 runtime read" — wildly outdated.
2. **JS_VKeys_GetState 28x/frame**: keyboard.lua:22 calls the API inside the key loop. Hoist to one call per frame.
3. **preferences_store desynced**: UI mutates config.state directly without updating preferences_store. Values lost on next SyncFromState().
4. **preset_browser.Init() every frame**: Called unconditionally in MainLoop. Guard with `if preset_root == "" then return end`.

### Sprint 1 — Store Migration

- All config.state reads → preferences_store getters across views.lua (51), pads.lua, drag.lua, sequencer.lua, keyboard.lua temp_ctx
- Update root AGENTS.md remnant count from "~1" to actual
- Remove `config.state` from all getter/setter paths

### Sprint 2 — Monolith Extraction

- **interaction.lua** (1051 LOC): extract note placement, drag, lasso, tool dispatch into separate modules
- **views.lua** (801 LOC): extract island rendering, transport, layout section into submodules under ui/

### Sprint 3 — Feature Gaps

- Pad velocity humanization (match keyboard's `85 + math.random(30)`)
- MIDI channel selector in UI
- Chord modes: sus2, sus4, dim, aug, 11th, 13th
- MIDI CC output (mod wheel, expression)
- Sustain pedal (CC 64) support

### Sprint 4 — Polish

- 49 stale SPDX headers (all still say "Andrik on the beat")
- PITCH_ROW_H table/string hack in piano-roll barrel
- AGENTS.md outdated line counts (island.lua says 136, actual 566)

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Scope creep — 17 items is a LOT | High | Sprint 0 is the only commitment. User picks subsequent sprints. |
| config.state migration touches 12+ files | Med | Do Sprint 0 then immediately Sprint 1 before other branches diverge. |
| User doesn't need some features | Low | Proposal groups by sprint. User decides. Nothing is committed. |

## Rollback Plan

No code in this phase — rollback is discarding the proposal doc. Individual git revert per sprint if implemented.

## Dependencies

None — planning artifact only.

## Success Criteria

- [ ] 17+ findings organized into ≤5 workstreams with clear entry/exit
- [ ] Each workstream is independently actionable
- [ ] User can make an informed decision on which sprint to tackle
- [ ] Zero implementation code written — purely organizational
