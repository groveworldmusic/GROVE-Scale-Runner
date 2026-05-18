# SDD Proposal: Massive Bug Sweep

**Change name**: Massive Bug Sweep — Presets, Persistence, Pads, Transport
**Project**: GROVE FL MIDI
**Date**: 2026-05-16
**Author**: SDD Proposer (StepFun step-3.5-flash)
**Execution mode**: auto (no pauses)
**Artifact store**: hybrid (Engram + openspec files)
**Delivery strategy**: auto-chain (single PR recommended)

---

## Executive Summary

Address a critical collection of bugs across multiple subsystems: state persistence (use_scroll, color_mode, window positions), preset browser (incomplete state clearing, unsafe deserialization), pad rendering (nil crashes), and compact panel position persistence. The fixes are localized, low-risk, and focus on adding missing validation, extending the persistence registry, and ensuring proper state synchronization after `persist.Load()`.

---

## Scope

### Files to Modify

| File | Purpose |
|------|---------|
| `src/state/persist.lua` | Add `use_scroll` and `compact_panel_x/y` to `PREF_KEYS` registry |
| `src/state/preset-store.lua` | Fix `ClearBrowserState()` to also reset `folder_scroll` |
| `src/ui/preset-browser/io.lua` | Replace unsafe `load()` in `LoadFavorites()` with a safe manual parser |
| `src/ui/pads.lua` | Add nil-guard when accessing `config.VKEY_MAP[state.code]` |
| `src/main.lua` | After `SyncFromState()`, manually sync `ui_store` fields: `color_mode`, `view_offset_x`, `view_offset_y` |
| `src/config.lua` | (No change needed—`compact_panel_x/y` already exist in `config.state`) |

### Affected Stores

- `persist` — key registry extension
- `preset-store` — ClearBrowserState behavior
- `preferences` — already supports `compact_panel_x/y` setters/getters; will now persist
- `ui` — new sync from `config.state` post-load

---

## Approach

### 1. Persistence Registry Update

**Problem**: `use_scroll` and `compact_panel_x/y` are not in `persist.PREF_KEYS`, so they never get saved to or loaded from ExtState.

**Fix**: In `src/state/persist.lua`, extend the `PREF_KEYS` table:
```lua
local PREF_KEYS = {
    ...existing keys...,
    use_scroll = "use_scroll",
    compact_panel_x = "compact_panel_x",
    compact_panel_y = "compact_panel_y",
}
```

### 2. UI State Synchronization

**Problem**: `persist.Load()` writes values into `config.state`, but `ui_store` was initialized before `persist.Load()` and never receives those restored values. This affected `color_mode`, `view_offset_x`, `view_offset_y`.

**Fix**: In `src/main.lua`, immediately after `preferences_store.SyncFromState(config.state)`, add:
```lua
ui_store.SetColorMode(config.state.color_mode or "grade")
ui_store.SetViewOffsetX(config.state.view_offset_x or 200)
ui_store.SetViewOffsetY(config.state.view_offset_y or 0)
```

### 3. ClearBrowserState Completeness

**Problem**: `preset_store.ClearBrowserState()` reset most fields but omitted `folder_scroll`, leaving stale scroll offset.

**Fix**: Add `state.folder_scroll = 0` to `ClearBrowserState()` in `src/state/preset-store.lua`.

### 4. LoadFavorites Security

**Problem**: `io.LoadFavorites()` used `load("return " .. str)` on ExtState data, which can execute arbitrary code if the string is tampered with.

**Fix**: Replace the `load` call with a manual parser:
- Validate string starts with `{` and ends with `}`
- Split by commas inside top-level braces
- Trim quotes from each string literal
- Build favorites table with `favs[path] = true`
- Keep `pcall` around parsing to catch malformed data

### 5. Pad Nil-Protection

**Problem**: `pads.DrawScalePad()` line 32 accessed `config.VKEY_MAP[state.code].deg` without checking that `config.VKEY_MAP[state.code]` exists, causing crashes when `state.code` is not a mapped key.

**Fix**: Change to:
```lua
local vkey = config.VKEY_MAP[state.code]
if vkey and vkey.deg == degree then active = true break end
```

### 6. Compact Panel Persistence Activation

**Problem**: Although `preferences_store` already has `compact_panel_x/y` fields and persist key registry was missing them, they were never loaded/saved.

**Fix**: By adding them to `persist.PREF_KEYS`, the existing `SetCompactPanelX/Y` (debounced) and `SyncFromState` will automatically start persisting and restoring the panel position across sessions.

---

## Risks & Mitations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| State migration corruption | Low | Medium | New keys are additive; missing ExtState falls back to defaults. No data loss. |
| Performance regression from manual parser | Very Low | Negligible | Favorites load happens once per session; parser is O(n) with tiny n (user presets). |
| Backward compatibility break | Very Low | Low | ExtState namespace unchanged; older versions ignore new keys. Manual parser accepts same format as before. |
| Overriding user-set `color_mode` on every launch | Medium | Medium | The synchronization copies the persisted value; this is the desired behavior. Users who changed `color_mode` during the session have it saved and will see it restored. |

---

## Size Estimate

~50–70 changed lines total across 5 files.

Detailed:
- `persist.lua`: +2 lines
- `preset-store.lua`: +1 line
- `preset-browser/io.lua`: ~25 lines (parser rewrite)
- `pads.lua`: +2 lines
- `main.lua`: +4 lines

---

## Chain Strategy Recommendation

**Single PR (main branch)**
- The change is well under 400 lines and consists of independent, isolated fixes.
- Each fix can be reviewed separately even within one PR.
- No complex inter-dependencies that would mandate stacking.

If later inspection reveals more than 100 lines of additional related fixes (unlikely), consider splitting by area:
1. Persistence and UI sync
2. Preset browser
3. Pads safety

But based on current inventory, a single PR is sufficient and preferable.

---

## Artifacts

This proposal will be saved to:
- Engram with `topic_key = sdd/all-bugs-sweep/proposal`
- `openspec/changes/2026-05-16-massive-bug-sweep/proposal.md`
