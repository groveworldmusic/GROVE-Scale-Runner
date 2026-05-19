# progression-tests Specification

## Purpose

Validate `core.progression` CRUD operations — Add, Remove, Swap, Clear, and GetLastFilled — using the real module via `require("core.progression")`.

## Requirements

| ID | Requirement | Scenarios |
|----|------------|-----------|
| P1 | `Add(idx, slot)` MUST set the entry at idx and set flash highlight | GIVEN empty store WHEN Add(3, {degree=1}) THEN GetProgressionEntry(3)=slot. GIVEN Add at position 1..16 AFTER clearing THEN entry exists at that position |
| P2 | `Remove(idx)` MUST set entry to nil | GIVEN an entry at position 5 WHEN Remove(5) THEN GetProgressionEntry(5)=nil |
| P3 | `Swap(a, b)` MUST exchange values when a≠b | GIVEN entries A at 2 and B at 5 WHEN Swap(2,5) THEN GetProgressionEntry(2)=B AND GetProgressionEntry(5)=A |
| P4 | `Swap(a, a)` MUST NOT change anything | GIVEN an entry at position 3 WHEN Swap(3,3) THEN entry is unchanged |
| P5 | `Clear()` MUST empty all 16 slots | GIVEN 5 filled slots at positions 1,4,7,10,13 WHEN Clear() THEN GetProgressionEntry(i)=nil for all i, GetLastFilled()=0 |
| P6 | `GetLastFilled()` MUST return 0 on empty store | GIVEN no entries (after Init or Clear) WHEN GetLastFilled() THEN returns 0 |
| P7 | `GetLastFilled()` MUST return highest filled index (1-16) | GIVEN entries at positions 3 and 7 WHEN GetLastFilled() THEN returns 7 |

## Edge Cases

- Remove on already-empty position: no error, no state change
- Add at indices outside 1-16: store stores it per table semantics (no guard expected)
- Swap where one index has nil and the other has a value: nil is swapped correctly
