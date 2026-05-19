# Key Mapping Specification

**Domain**: key-mapping
**Change**: expansion-features (P2)
**Type**: New — no existing spec

## Purpose

Allow users to remap which piano degree each keyboard key triggers without editing `config.lua`. The 28 VK codes (4 rows × 7 degrees) remain fixed; only the `{deg, oct}` mapping is configurable. Persisted via ExtState, survives script reload.

## Requirements

### Requirement: VKEY_MAP Loader

`src/core/vkey-map.lua` MUST export `GetVKeyMap()` returning a table `{[vk_code] = {deg, oct}}`. If a persisted override exists in ExtState, it SHALL be loaded via `load()`. If no override exists, return `config.VKEY_MAP` as fallback.

#### Scenario: No persisted map uses config defaults

- GIVEN no `vkey_map` key exists in ExtState
- WHEN `vkey_map.GetVKeyMap()` is called
- THEN it SHALL return `config.VKEY_MAP` (unchanged reference)

#### Scenario: Persisted map overrides defaults

- GIVEN a persisted `vkey_map` string `"return {[0x51]={deg=5, oct=0}}"` in ExtState
- WHEN `vkey_map.GetVKeyMap()` is called
- THEN `VKEY_MAP[0x51]` SHALL be `{deg=5, oct=0}`

### Requirement: Mapping Modification

`vkey-map.lua` MUST export `SetVKeyMapping(vk_code, new_deg, new_oct)` that updates the in-memory map, serializes the full 28-entry map to a Lua table string, and calls `persist.Save("vkey_map", serialized)`. `ResetToDefaults()` MUST clear the override and restore `config.VKEY_MAP`.

#### Scenario: Remap a single key

- GIVEN the default VKEY_MAP (0x51 → deg=0)
- WHEN `vkey_map.SetVKeyMapping(0x51, 5, 0)` is called
- THEN `GetVKeyMap()[0x51]` SHALL be `{deg=5, oct=0}`
- AND the serialized map SHALL be written to ExtState

#### Scenario: Reset clears override

- GIVEN a modified VKEY_MAP exists
- WHEN `vkey_map.ResetToDefaults()` is called
- THEN `GetVKeyMap()` SHALL return `config.VKEY_MAP`
- AND the `vkey_map` ExtState key SHALL be removed or set to empty

### Requirement: keyboard.lua Integration

`src/core/keyboard.lua` MUST import VKEY_MAP from `vkey-map.lua` instead of `config.VKEY_MAP`. On VKEY_MAP modification, `keyboard.RebuildKeyStates()` SHALL be called to clear and rebuild `midi_store.GetKeyStates()` — preventing stale entries.

#### Scenario: Remap triggers key_states rebuild

- GIVEN `midi_store.GetKeyStates()` has 28 entries for default map
- WHEN `SetVKeyMapping(0x51, 5, 0)` completes
- THEN `RebuildKeyStates()` SHALL execute
- AND `midi_store.GetKeyStates()` SHALL have 28 clean entries with updated `{deg, oct}` for the remapped key

### Requirement: Remap UI

The settings panel SHALL show the 4 rows × 7 degrees grid. Each cell SHALL display its current `{deg, oct}` with dropdown-based remap controls. A "Reset to Defaults" button SHALL call `ResetToDefaults()`.

#### Scenario: Remap dropdown changes mapping

- GIVEN the settings panel is open showing key 0x51 (Q)
- WHEN the user changes its degree from 0 to 5 via dropdown
- THEN `SetVKeyMapping(0x51, 5, -1)` SHALL be called
- AND the UI SHALL update to show the new mapping

#### Scenario: Reset button clears all changes

- GIVEN 3 keys have been remapped
- WHEN the user clicks "Reset to Defaults"
- THEN ALL keys SHALL return to their `config.VKEY_MAP` values
- AND `midi_store.GetKeyStates()` SHALL be rebuilt

## Non-Goals

- Per-scale key maps (single global VKEY_MAP)
- Per-mode key maps (same map for chord/scale/arp modes)
- Full key-binding editor with conflict detection
- Changing VK codes (only `{deg, oct}` remappable)
- MIDI learn for keyboard mapping

## Dependencies

- **Builds on**: `persist.Save` for ExtState serialization (existing), `config.VKEY_MAP` as default (existing)
- **P2 → P1, P3**: P2 depends on P1's `preferences_store` pattern but not on P1's theme feature. P2 header additions (remap button) share header space with P1 (theme dropdown) and P3 (record toggle). P2 modifies `keyboard.lua` — watch for merge conflicts if other batches touch it.
- **Risk**: Serialization of full 28-entry table to a single ExtState string — verify string length limits (~32KB in REAPER ExtState, safe for <1KB map)

## Test Requirements

| Assertion | Type |
|-----------|------|
| `GetVKeyMap()` returns default when no override | Unit |
| `GetVKeyMap()` returns override after `SetVKeyMapping` | Unit |
| Serialized map roundtrips via `load()` | Unit |
| `ResetToDefaults()` clears persisted override | Unit |
| `RebuildKeyStates()` produces 28 entries matching current map | Unit |
| Stale VK code removed from key_states after remap that key | Unit |
