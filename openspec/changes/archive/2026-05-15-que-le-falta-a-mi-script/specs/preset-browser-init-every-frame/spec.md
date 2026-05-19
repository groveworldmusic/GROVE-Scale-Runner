# Spec: preset_browser.Init() Every Frame

## Description
`preset_browser.Init()` is called unconditionally from `midi-island.lua:49` in the main loop. If `preset_root` is empty (e.g. `reaper.GetResourcePath()` fails), this triggers I/O every frame.

## Requirements
1. `preset_browser.Init()` is called at most once (first frame after module load)
2. A module-level `_preset_init_attempted` flag tracks whether Init() has been called
3. If `preset_root` is empty after first attempt, no further Init() calls are made
4. No behavioral change when preset_root is valid — Init() runs once as before

## Scenarios
- **Happy path**: preset_root is valid → Init() runs once, subsequent frames skip
- **Edge case**: preset_root is empty → Init() still runs first attempt; flag prevents I/O spam on subsequent frames

## Files Affected
- `src/ui/midi-island.lua`: ~10 lines changed (add flag, guard condition)

## Estimated LOC
~10 lines changed
