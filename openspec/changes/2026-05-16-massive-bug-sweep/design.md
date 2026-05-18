# Design: Massive Bug Sweep — Presets, Persistence, Pads, Transport

## Technical Approach

Address a critical collection of bugs across multiple subsystems through additive, non-breaking changes:

1. Extend the persistence registry (`persist.PREF_KEYS`) to include missing keys.
2. Synchronize UI store fields after loading persisted state.
3. Fix `ClearBrowserState()` to reset all browser-related fields.
4. Replace unsafe `load()` deserialization in `LoadFavorites()` with a manual parser.
5. Add nil-guard for `VKEY_MAP` access in pad rendering.
6. Activate compact panel position persistence via registry.

All changes maintain backward compatibility and follow the existing Init order and store patterns.

## Architecture Decisions

### Decision: Additive Persistence Registry Extension

**Choice**: Add `use_scroll`, `compact_panel_x`, and `compact_panel_y` to `persist.lua`'s `PREF_KEYS` table as direct string keys.

**Alternatives considered**:
- Create a separate persistence mechanism for UI state.
- Modify `config.state` mutation directly without registry.

**Rationale**: Consistency. All persisted preferences flow through the same registry with canonical/legacy namespace migration. This ensures future-proofing and avoids code duplication.

### Decision: Manual Post-Load UI State Sync

**Choice**: In `main.lua`, immediately after `preferences_store.SyncFromState(config.state)`, call:
```lua
ui_store.SetColorMode(config.state.color_mode or "grade")
ui_store.SetViewOffsetX(config.state.view_offset_x or 0)
ui_store.SetViewOffsetY(config.state.view_offset_y or 0)
```

**Alternatives considered**:
- Add `ui_store.SyncFromState()` method and call it alongside `preferences_store`.
- Have `ui_store.Init()` defer to `config.state` after `persist.Load()`.

**Rational**: Minimal change. Only three fields need this one-time sync. Adding a dedicated method is overkill for a single use case, and altering `Init` semantics risks affecting other stores.

### Decision: Safe Favorites Parser

**Choice**: Replace `pcall(load("return " .. str))` with a manual parser that:
- Validates the string starts with `{` and ends with `}`.
- Splits by commas while ignoring commas inside quoted strings.
- Strips surrounding quotes from each string literal.
- Builds a `{[path] = true}` table.
- Wraps parsing in `pcall` to catch any malformed data and return an empty table.

**Alternatives considered**:
- Use a JSON library (adds dependency).
- Keep `load()` but sandbox the environment (complex, still risky).
- Force migration to a different format (breaks backward compatibility).

**Rationale**: Zero external dependencies, safe, maintains exact same on-disk format (`{"path1","path2",...}`), and preserves compatibility with existing saved favorites.

### Decision: Nil-Guard VKEY_MAP Access

**Choice**: In `pads.DrawScalePad()`, change:
```lua
if state.is_pressed and config.VKEY_MAP[state.code].deg == degree then
```
to:
```lua
local vk = config.VKEY_MAP[state.code]
if state.is_pressed and vk and vk.deg == degree then
```

**Alternatives considered**:
- Ensure all possible key codes are mapped at init (impractical; unknown codes can come from other sources).
- Wrap the entire loop in pcall (hides other errors, performance cost).
- Filter key_states ahead of time to only mapped codes (adds complexity).

**Rationale**: Defensive programming. Some `key_code` entries may not be in `VKEY_MAP` (e.g., stray state from other modules). A simple nil-check prevents crashes without overhead.

### Decision: Complete Browser State Clearing

**Choice**: In `preset_store.ClearBrowserState()`, append `state.folder_scroll = 0` to reset the folder navigation scroll offset.

**Alternatives considered**:
- Expose `SetFolderScroll(0)` separately — less cohesive.
- Leave `folder_scroll` untouched — leaves stale state.

**Rationale**: `ClearBrowserState()` must reset *all* browser UI state to defaults. Omitting `folder_scroll` leaves the UI in an inconsistent position after a clear operation.

## Data Flow

### Persistence Load and UI Sync

```
config.state (defaults)
    ↓
persist.Load(config.state)
    ├─ Read canonical namespace (GROVE_Scale_Runner)
    ├─ Fallback to legacy (GROVE_FL_MIDI) with migration
    └─ Write coerced values into config.state
    ↓
preferences_store.SyncFromState(config.state)
    └─ Copy 7 prefs + compact_panel_x/y into prefs_state
    ↓
main.lua: manual ui_store sync
    ├─ ui_store.SetColorMode(config.state.color_mode or "grade")
    ├─ ui_store.SetViewOffsetX(config.state.view_offset_x or 0)
    └─ ui_store.SetViewOffsetY(config.state.view_offset_y or 0)
```

### Favorites Load (Safe Parser)

```
reaper.GetExtState("GROVE_Scale_Runner", "preset_favorites")
    ↓
if string not empty:
  - Validate: string starts with '{' and ends with '}'
  - Strip outer braces → inner = str:sub(2, -2)
  - Split inner by ',' respecting quoted strings:
      * Simple loop tracking quote depth; split only at commas when depth==0
  - For each segment: trim whitespace, strip leading/trailing quotes
  - Validate each resulting path is a non-empty string
  - Build favorites = { [path] = true }
else
  favorites = {}
pcall → on error, favorites = {}
    ↓
preset_store.SetFavorites(favorites)
```

### Pad Rendering with VKEY Nil-Guard

```
midi_store.GetKeyStates() returns { [code] = {is_pressed, midi_notes, code}, ... }
For each state:
    local vk = config.VKEY_MAP[state.code]   -- may be nil
    if vk and vk.deg == degree then active = true; break; end
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/state/persist.lua` | Modify | Add `use_scroll`, `compact_panel_x`, `compact_panel_y` to `PREF_KEYS` table (lines ~18-31). |
| `src/main.lua` | Modify | After `preferences_store.SyncFromState(config.state)` (around line 433), add three `ui_store.Set*` calls with nil-defaults. |
| `src/state/preset-store.lua` | Modify | In `ClearBrowserState()`, append `state.folder_scroll = 0`. |
| `src/ui/preset-browser/io.lua` | Modify | Replace `pcall(load(...))` in `LoadFavorites()` (lines ~284-296) with manual parser implementation (~20-25 lines). |
| `src/ui/pads.lua` | Modify | In `DrawScalePad()` active note detection (line ~32), add nil-check: `local vk = config.VKEY_MAP[state.code]; if vk and vk.deg == degree then ...`. |
| `src/config.lua` | None | `compact_panel_x/y` already present in `config.state`; no change needed. |

## Interfaces / Contracts

- **persist.PREF_KEYS**: Extended with three new entries. Values are strings mapping directly to `config.state` keys. No structural changes to `Load`/`Save`.
- **main.lua**: Calls existing `ui_store` setters; no new functions introduced.
- **preset_store.ClearBrowserState()**: Guarantees `folder_scroll` resets to 0.
- **io.LoadFavorites()**: Accepts ExtState string in format `{"path","...`, returns `{ [path] = true }` or `{}` on error. Parser must handle whitespace and quoted strings safely.
- **pads.DrawScalePad()**: Reads `config.VKEY_MAP[code]` safely; if missing, the key state is ignored.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `persist.Load` new keys | Mock `reaper.GetExtState` to return values for `use_scroll`, `compact_panel_x`, `compact_panel_y`; verify they appear in `config.state` and post-`SyncFromState` in `prefs_state` (compact) and `ui_state` (manual). |
| Unit | `LoadFavorites` parser | Feed valid JSON-like string, empty string, malformed strings, strings with escaped quotes (edge), whitespace variations. Expect correct table or `{}`. |
| Unit | `ClearBrowserState` | Call function; assert `preset_store.GetFolderScroll() == 0` and all other fields at defaults. |
| Integration | Startup state restore | Set ExtState values, launch script; verify `ui_store.GetColorMode()`, `GetViewOffsetX()`, `GetViewOffsetY()`, `GetUseScroll()` match persisted values. |
| Integration | Pad safety | Simulate a `key_state` with a code not in `VKEY_MAP` (e.g., 0xFF); ensure `DrawScalePad` does not crash and pad renders as inactive. |

Manual smoke tests after implementation:
- Toggle `color_mode` (grade/flat), restart → restored.
- Move window (view_offset_x/y), restart → restored.
- Enable/disable `use_scroll`, restart → restored.
- Add/remove favorites, restart → favorites persist without error.
- Clear browser state (e.g., via preset browser reset) → folder_scroll resets to 0.
- Press an unmapped key, observe no crash in scale pad rendering.

## Migration / Rollout

**No data migration required**. Changes are additive:
- New persistence keys are registered; missing ExtState falls back to defaults (`0` for numeric, `"grade"` for color_mode, etc.).
- Manual parser accepts identical format as previous `load()`; existing `preset_favorites` strings parse unchanged.
- `ui_store` sync intentionally overwrites store defaults with persisted values — this is the desired behavior to restore user preferences across sessions.

Legacy namespace values (`GROVE_FL_MIDI`) continue to be migrated by `persist.Load()` on first access, as before.

## Open Questions

None — implementation is straightforward and self-contained.
