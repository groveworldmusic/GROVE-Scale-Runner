# Preset Multi-Select Specification

## Purpose

Set-based multi-selection for preset lists, decoupled from any specific UI. Replicates the proven pattern from `island.lua` (`selected_indices = {[idx]=true}`) with modifier-key dispatch: plain click replaces, Ctrl+click toggles, Shift+click ranges.

## Requirements

### Requirement: Set-Based Store API

The preset state store MUST provide the following selection API:

| Function | Signature | Behavior |
|----------|-----------|----------|
| `GetSelectedIndices` | `() → table` | Returns the `{[idx]=true}` set (mutable ref) |
| `SetSelectedIndices` | `(t)` | Atomically replaces the selection set |
| `ClearSelection` | `()` | Empties selection set and anchor |
| `IsSelected` | `(idx) → bool` | Checks set membership |
| `ToggleSelected` | `(idx)` | Toggles membership; updates anchor to this index if newly selected |
| `GetPrimarySelectedIndex` | `() → idx\|nil` | Returns the anchor (most recently toggled index) |
| `GetSelectionCount` | `() → number` | Count of selected indices |
| `GetSelectionAnchor` | `() → idx\|nil` | Returns the anchor for Shift-range computation |
| `SetSelectionAnchor` | `(idx)` | Explicitly sets the anchor |
| `RemoveSelectionFixup` | `(removed_idx)` | Decrements all keys greater than `removed_idx`; removes key equal to `removed_idx` |

#### Scenario: Toggle membership

- GIVEN an empty selection set
- WHEN `ToggleSelected(3)` is called
- THEN `IsSelected(3)` returns true AND `GetPrimarySelectedIndex()` returns 3

#### Scenario: Fixup after non-adjacent delete

- GIVEN `selected_indices = {[2]=true, [5]=true, [7]=true}`
- WHEN `RemoveSelectionFixup(5)` is called
- THEN `selected_indices` becomes `{[2]=true, [6]=true}` — keys > 5 decremented, key 5 removed

### Requirement: Modifier Interaction Model

Clicking a preset item SHALL dispatch according to modifier keys. The anchor tracks the last Ctrl+clicked or plain-clicked index. Shift+click selects the inclusive range [anchor, clicked]. If no anchor exists, Shift+click behaves as plain click.

#### Scenario: Plain click replaces selection

- GIVEN `{[2]=true, [5]=true}` selected
- WHEN user plain-clicks index 3
- THEN `GetSelectedIndices()` returns `{[3]=true}` AND anchor = 3

#### Scenario: Ctrl+click toggles item

- GIVEN `{[2]=true, [5]=true}` selected
- WHEN user Ctrl+clicks index 3
- THEN `GetSelectedIndices()` returns `{[2]=true, [3]=true, [5]=true}` AND anchor = 3

#### Scenario: Shift+click selects range

- GIVEN anchor = 2 and `{[2]=true, [5]=true}`
- WHEN user Shift+clicks index 7
- THEN `GetSelectedIndices()` = `{[2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [7]=true}`

#### Scenario: Shift+click with no anchor

- GIVEN `GetSelectionAnchor()` returns nil
- WHEN user Shift+clicks index 4
- THEN only `{[4]=true}` is selected (plain click behavior)
