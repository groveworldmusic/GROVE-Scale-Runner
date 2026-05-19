# store-tests Specification

## Purpose

Validate all 5 state stores (`compact`, `drag`, `sequencer`, `midi`, `ui`) — Init defaults, getter/setter round-trips, consumable patterns, and edge cases.

## Requirements

| ID | Requirement | Scenario |
|----|------------|----------|
| S1 | `Init(defaults)` MUST set defaults for every field per store's merge semantics | GIVEN empty table init WHEN check defaults THEN compact has 6 fields (nil/false), drag 9 (false/-1/nil/0), sequencer 14 (false/0/-1/nil/100/1/{}), midi 6+3 (false/"None"/0/{}/{}/{}), ui 14 (1/false/0/"grade"/{}/etc) |
| S2 | Every getter/setter pair MUST round-trip: set X returns X | GIVEN each store WHEN set every field to a non-default value THEN each getter returns the set value. compact: 6 pairs, drag: 9 pairs, sequencer: 14+4+2+2 pairs, midi: 3+6+ClearActiveNotes, ui: 14+2 Consume+3 pad flash |
| S3 | `ui_store.ConsumeMouseClick()` MUST return true once then false | GIVEN SetMouseClick(true) WHEN ConsumeMouseClick() THEN true. WHEN called again THEN false |
| S4 | `ui_store.ConsumeMouseWheelDelta()` MUST return delta once then zero | GIVEN SetMouseWheelDelta(5) WHEN ConsumeMouseWheelDelta() THEN 5. WHEN called again THEN 0 |
| S5 | Setting nil or wrong types MUST NOT crash the store | GIVEN any setter WHEN called with nil or mismatched type THEN no error is raised (value stored as-is) |
| S6 | `drag_store.Reset()` MUST clear all drag fields to defaults | GIVEN non-default drag state WHEN Reset() THEN is_dragging=false, source_degree=-1, source_slot_idx=-1, pending_degree=nil, pending_slot_idx=nil |
| S7 | `sequencer.ClearProgression()` MUST nil all 16 slots | GIVEN 5 entries at positions 1,4,7,10,13 WHEN ClearProgression() THEN progression[i]=nil for i=1..16 |

## Edge Cases

- Re-Init() with different defaults: previous values are overwritten according to merge semantics
- `GetMousePadState()` returns ref to mutable table — mutations affect internal state
- `GetProgression()` returns ref — mutations visible to store
