# Design: Sprint 0 — Critical Bugs

## Fix 1: JS_VKeys_GetState Hoisting
Hoist `reaper.JS_VKeys_GetState(0)` from inside the key iteration loop (28 calls/frame) to before it (1 call/frame). Guard stays at loop level. Zero behavioral change. File: `src/core/keyboard.lua`, ~4 lines changed.

## Fix 2: preferences_store Desync
Add `prefs.Set*()` calls after every `config.state.*` mutation in UI code. 31 sites across 3 files (views.lua, compact-menu.lua, compact-init.lua). Add `require("state.preferences")` to each file. Fixes stale store reads that don't reflect UI changes.

## Fix 3: preset_browser.Init() Every Frame
Guard `preset_browser.Init()` with module-level `_preset_init_attempted` flag in midi-island.lua. First frame calls Init(), subsequent frames skip. Reset flag on preset_root change. Eliminates ~60 file-stat calls/second.

## Fix 4: Documentation Stale Counts
Update LOC counts in all 4 AGENTS.md files (root, core, ui, state) to match source reality. Key updates: views.lua 654→867, midi-island.lua 132→205, interaction.lua 795→1176, island.lua 136→567, config.state refs ~1→~138.

**Delivery**: Single PR, ~100 lines total, low risk.
