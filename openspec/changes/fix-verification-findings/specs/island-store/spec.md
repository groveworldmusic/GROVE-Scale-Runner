# island-store Specification (Delta)

## MODIFIED Requirements

### Requirement: Store API Surface

The store MUST expose getter/setter pairs for: `ScrollX(number)`, `Zoom(number 0.25-4.0)`, `PrimarySelectedNoteIndex(number|nil)`, `SelectedPreset(string|nil)`, `ToolMode(string)`, `LassoActive(boolean)`, `LassoStart/End({x,y})`. Note and selection proxies (`GetNotes`, `SetNotes`, `GetSelectedIndices`, etc.) MUST be removed. All consumers of these proxies MUST be retargeted to `note_store` or `preset_store` directly.
(Previously: Included note and selection proxies such as `GetNotes`, `SetNotes`, `GetSelectedIndices`, `IsNoteSelected`, `ToggleNoteSelected`, `AddNote`, `RemoveNoteAtIndex`, `GetNoteCount`, `SetNoteCount`, `ClearSelection`, etc.)

#### Scenario: Removal of GetNotes

- GIVEN an initialized island store
- WHEN `GetNotes()` is called
- THEN it MUST result in a runtime error (function not found)

#### Scenario: Retargeting selection

- GIVEN a consumer that previously used `island_store.GetSelectedIndices()`
- WHEN it is updated to use `note_store.GetSelectedIndices()`
- THEN it MUST receive the same selection data as before
