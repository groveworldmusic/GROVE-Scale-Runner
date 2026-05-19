# Tasks — Piano Roll Professional — Fase 2 (Musicality & Groove)

**Change**: `piano-roll-pro-fase2`
**Project**: `grove-scale-runner`
**Artifact store mode**: hybrid (openspec + Engram)
**Delivery strategy**: auto-chain
**Chain strategy**: feature-branch-chain

```
Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High
```

---

## Work-Unit PR Descriptions

### PR 1 — Slice A: Swing
Wire `quantize_swing` from `island_store` into the quantization pipeline and expose a Swing control in the Piano Roll header for real-time adjustment.

### PR 2 — Slice B: Humanize
Implement a `HumanizeNotes()` pure function, store the `humanize_strength` parameter in `island_store`, wire Ctrl+H to the operation, and add `"humanize"` as a recognised undo type.

### PR 3 — Slice C: Velocity Edits
Add absolute velocity set mode (Shift-drag) and a right-click context menu ("Reset to 100" / "Normalize") on the velocity bar editor.

### PR 4 — Slice D: Arpeggiator
Create `GenerateArpeggio()` to transform a chord selection into ascending/descending/random arpeggio sequences and insert them via `island_store.AddNote()`.

---

## Slice Dependencies

All four slices are independently implementable. No slice depends on another. The base for every slice is `feat/piano-roll-fase2` (or the PR branch of the prior slice when chaining).

---

## Phase 1 — Swing (~120 LOC)

### A.1 — Add `QuantizeBeatWithSwing` to core/quantize.lua

- [ ] A.1.1 Add `QuantizeBeatWithSwing(beat, resolution, strength, triplet, swing)` to `src/core/quantize.lua`
- [ ] A.1.2 Wrap `QuantizeBeat`: call it to get `nearest`, then apply partial-strength interpolation
- [ ] A.1.3 Detect off-beat: `local is_offbeat = (math.floor(beat / grid_size) % 2) == 1`
- [ ] A.1.4 When off-beat, append `offset = (swing / 100) * (grid_size / 2)`, clamped so result does not exceed next grid boundary
- [ ] A.1.5 Export the function in the module return table
- [ ] A.1.6 No changes to existing `QuantizeBeat()` or `QuantizeNote()` signatures — back-compat preserved

### A.2 — Add Swing UI control to header.lua

- [ ] A.2.1 In `src/ui/midi-island/header.lua`: compute the Swing control width and insert it **after** the QNTZ button (update `cur_x` after QNTZ block)
- [ ] A.2.2 Draw Swing as a compact dropdown button showing current `GetQuantizeSwing()` value (0–50), styled consistent with other header controls
- [ ] A.2.3 On click: open a `gfx.showmenu()` with options `0|5|10|15|20|25|30|35|40|45|50` pre-selecting current value (mark with `! `)
- [ ] A.2.4 On menu selection: call `island_store.SetQuantizeSwing(value)` and `ui_store.ConsumeMouseClick()`
- [ ] A.2.5 Tooltip: "Swing (0–50%): shifts off-beats toward the 2nd 16th within each beat pair"
- [ ] A.2.6 Add deduction: total header layout `content_w` centering math must include Swing width — update `total_header_w` sum if needed

### A.3 — Wire Swing into the Quantize shortcut handler

- [ ] A.3.1 In `src/ui/piano-roll/interaction/shortcuts.lua` → `HandleQuantize()`: after reading `snap_triplet` and `strength`, also read `swing = island_store.GetQuantizeSwing()`
- [ ] A.3.2 Replace the single `quantize.QuantizeNote(note_data, resolution, strength, triplet)` call at line 57 with a two-step: `quantize.QuantizeBeatWithSwing(note_data.start_beat, resolution, strength, triplet, swing)` for `q_start`, and keep `quantize.QuantizeNote()` for `q_end/q_dur` (no swing on duration)
- [ ] A.3.3 Retain full undo-entry construction (uuids, prev_states, new_states) — only the start_beat calculation changes
- [ ] A.3.4 Existing Ctrl+Q shortcut (char 113) needs no change — it routes through `HandleQuantize`

### A.4 — Verify

- [ ] A.4.1 Manual: Quantize with `swing=0`, verify off-beats snap to clean grid (same as pre-change)
- [ ] A.4.2 Manual: Set `swing=30`, Ctrl+Q, verify on-beats stay on-beats and off-beats shift right by `0.25 * grid_size / 2` (e.g., 1/8 off-beat at 1.5 → 1.5375 for 1/16 grid)
- [ ] A.4.3 Manual: Swing slider persistence — change value, restart script, verify it reports same value

---

## Phase 2 — Humanize (~180 LOC)

### B.1 — Create `src/core/humanize.lua`

- [ ] B.1.1 New file `src/core/humanize.lua`. Implement as a **pure function** module with zero store dependencies.
- [ ] B.1.2 Export `HumanizeNotes(notes, selected_indices, timing_range_pct, velocity_range)`
- [ ] B.1.3 Compute `grid_size = 4 / effective_res` (caller passes `snap_resolution` and `triplet` flag — see HandleHumanize wrapper)
- [ ] B.1.4 For each selected note: `timing_offset = (math.random() - 0.5) * (timing_range_pct / 100) * grid_size`, `note.start_beat = note.start_beat + timing_offset`
- [ ] B.1.5 For each selected note: `new_vel = clamp(note.velocity + (math.random() - 0.5) * velocity_range, 1, 127)`
- [ ] B.1.6 Returns **void** — mutates notes array in-place. No store reads or writes.

### B.2 — Add `humanize_strength` to island.lua

- [ ] B.2.1 Add `humanize_strength = 10` next to `quantize_swing` (line 62 area) in `src/state/island.lua`
- [ ] B.2.2 Add getter `m.GetHumanizeStrength() → number` (default 10)
- [ ] B.2.3 Add setter `m.SetHumanizeStrength(v)` — accept `v or 10`, clamp to 1–50 range

### B.3 — Create `src/ui/piano-roll/humanize.lua`

- [ ] B.3.1 New file `src/ui/piano-roll/humanize.lua` (~35 LOC). Wrapper reads island_store + note-store, calls `humanize.HumanizeNotes()`, pushes a single `"humanize"` undo entry.
- [ ] B.3.2 Export `HandleHumanize()`
- [ ] B.3.3 Read notes + selected indices from island_store; no-op (return silently) if `sel_count == 0`
- [ ] B.3.4 Read `timing_range_pct = island_store.GetHumanizeStrength()` and `velocity_range = 20` (hardcoded per spec)
- [ ] B.3.5 Derive `grid_size` from `island_store.GetSnapResolution()` + `GetSnapTriplet()` (same formula as quantize: `4 / (triplet ? res * 1.5 : res)`)
- [ ] B.3.6 Snapshot prev_state: `{start_beat, velocity}` for every affected note, push undo with type `"humanize"`
- [ ] B.3.7 After calling `HumanizeNotes`, build `new_state` with mutated values and push undo entry
- [ ] B.3.8 Undo entry shape: `{type="humanize", note_uuids=[...], prev_state=[{start_beat, velocity}], new_state=[{start_beat, velocity}]}`

### B.4 — Add Ctrl+H to shortcuts.lua

- [ ] B.4.1 In `src/ui/piano-roll/interaction/shortcuts.lua`: add `-- Ctrl+H (113 + 256 = 369)` handler at the end of the dispatcher (before the `return false`)
- [ ] B.4.2 Call `require("ui.piano-roll.humanize").HandleHumanize()` and return `true` on consumption
- [ ] B.4.3 No-change: existing Ctrl+H in `keyboard.lua` (char 336) stays separate — this is the piano-roll shortcut only

### B.5 — Add `"humanize"` to undo.lua

- [ ] B.5.1 In `src/ui/piano-roll/undo.lua` → `RestoreUndo()`: add `elseif entry.type == "humanize"` branch
- [ ] B.5.2 Restore: for each uuid in `note_uuids`, restore `notes[idx].start_beat` and `notes[idx].velocity` from `entry.prev_state[i]`
- [ ] B.5.3 In `RestoreRedo()`: add matching `"humanize"` branch that restores from `entry.new_state`
- [ ] B.5.4 Call `note.MarkNotesDirty()` and `note_store.RebuildUUIDIndex()` at the end, same as other branches

### B.6 — Re-export from piano-roll barrel

- [ ] B.6.1 In `src/ui/piano-roll.lua`: add `local humanize = require("ui.piano-roll.humanize")` at the top
- [ ] B.6.2 Add `piano_roll.HandleHumanize = humanize.HandleHumanize`

### B.7 — Verify

- [ ] B.7.1 Manual: Select 4 notes, Ctrl+H — verify slight timing jitter and velocity variation are visible in the piano roll
- [ ] B.7.2 Manual: No selection + Ctrl+H — verify no crash, no notes mutated
- [ ] B.7.3 Manual: Ctrl+Z (undo) after humanize — verify all notes return to exact pre-humanize positions and velocities
- [ ] B.7.4 Manual: Ctrl+Shift+Z (redo) — verify they humanize again

---

## Phase 3 — Velocity Edits (~220 LOC)

### C.1 — Add `shift_held` parameter to `HandleVelocityMouse`

- [ ] C.1.1 In `src/ui/velocity.lua`: change signature to include `shift_held` boolean at the end
  ```lua
  function velocity.HandleVelocityMouse(mx, my, grid_x, ed_y, ed_h,
                                        scroll_x, zoom_x, click, mouse_down, shift_held)
  ```
- [ ] C.1.2 Propagate `shift_held` through: initial-click handler, drag-continuation handler, and `ApplyVelocity` helper

### C.2 — Implement absolute set mode in `ApplyVelocity`

- [ ] C.2.1 In `src/ui/velocity.lua` → `ApplyVelocity(notes, idx, new_vel, shift_held)` — add `shift_held` parameter
- [ ] C.2.2 When `shift_held == true` **and** `sel_count > 1`: set **all selected** notes to `new_vel` exactly (absolute value, no delta)
- [ ] C.2.3 When `shift_held == false` (default): retain existing relative delta behaviour unchanged
- [ ] C.2.4 Clarify in comment: `-- RELATIVE mode (shift_held=false, existing behaviour)`

### C.3 — Pass `shift_held` from `input.lua`

- [ ] C.3.1 In `src/ui/midi-island/input.lua`: at the `velocity.HandleVelocityMouse(...)` call site (near line 275), append `(gfx.mouse_cap & 4) == 4` as the last argument
- [ ] C.3.2 `gfx.mouse_cap & 4` is REAPER's Shift key flag — already read at line 56 as `ctrl_held`; `shift_held` is a separate read

### C.4 — Add right-click context menu in velocity.lua

- [ ] C.4.1 In `src/ui/velocity.lua`: after the `if drag_active and not mouse_down then` release block (line ~418), detect right-click: `(gfx.mouse_cap & 2) == 2 and last_mouse_cap_held` — use a module-local `rc_down` flag to detect rising edge
- [ ] C.4.2 On right-click in expanded velocity area (after stale-drag reset), call `gfx.showmenu("Reset to 100|Normalize")`
- [ ] C.4.3 **"Reset to 100"**: loop all selected indices → `notes[idx].velocity = 100`; push `{type="velocity", note_uuids, prev_state, new_state}`
- [ ] C.4.4 **"Normalize"**: scan selected notes for `min_v / max_v`; if equal, no-op; else `scaled = 1 + (v - min_v) / (max_v - min_v) * 126`, `math.floor(scaled + 0.5)`; push undo
- [ ] C.4.5 Right-click detection must only fire when velocity panel is expanded (`expanded == true`)

### C.5 — Verify

- [ ] C.5.1 Manual: Select multiple notes, Shift-drag one velocity bar — verify ALL selected bars jump to same value (absolute mode)
- [ ] C.5.2 Manual: Release Shift + drag — verify relative delta behaviour is unchanged
- [ ] C.5.3 Manual: Right-click velocity bar, "Reset to 100" — verify all selected notes show 100
- [ ] C.5.4 Manual: Right-click, "Normalize" — verify lowest → 1, highest → 127, mid values proportionally scaled
- [ ] C.5.5 Manual: Ctrl+Z after Reset/Normalize — verify velocity values are restored

---

## Phase 4 — Arpeggiator (~240 LOC)

### D.1 — Create `src/ui/piano-roll/arpeggiator.lua`

- [ ] D.1.1 New file `src/ui/piano-roll/arpeggiator.lua` (~50 LOC)
- [ ] D.1.2 Export `GenerateArpeggio(notes, selected_indices, direction, speed_beats, pattern)`
- [ ] D.1.3 Step 1: collect notes at selected indices, sort ascending by `pitch` field → `sorted_notes`
- [ ] D.1.4 Step 2: build walk order per `direction`:
  - `"Up"`: forward through `sorted_notes`
  - `"Down"`: backward through `sorted_notes`
  - `"UpDown"`: forward then backward (omit pivot to avoid duplicate)
  - `"Random"`: `sorted_notes[math.random(#sorted_notes)]` each step
- [ ] D.1.5 Step 3: emit one new note per walk step starting at `seed_beat = first_selected.start_beat`
  - `start_beat = seed_beat + step_index * speed_beats`
  - `duration = speed_beats` for `Staccato`; inherit original `note.duration` for `Sustain`
- [ ] D.1.6 Step 4: insert each generated note via `island_store.AddNote(note)` — assigns UUID automatically
- [ ] D.1.7 Return `{generated_uuids, generated_notes}` for undo tracking
- [ ] D.1.8 Settings default inline: `direction="Up"`, `speed_beats=1/16 (0.0625)`, `pattern="Staccato"`
- [ ] D.1.9 No-op when selection is empty or fewer than 2 notes (arpeggio of 1 note is a no-op)

### D.2 — Create `src/ui/piano-roll/humanize.lua` (shortcuts wrapper)

**Note:** this is Label D.2 — the humanize shortcut wrapper. See Phase 2 for the humanize pure function and island store field.

- [ ] D.2.1 See Phase 2, tasks B.3 through B.6 (already detailed there — do not duplicate)

### D.3 — Add `'A'` (char 65) shortcut to shortcuts.lua

- [ ] D.3.1 In `src/ui/piano-roll/interaction/shortcuts.lua`: add char 65 handler  
  ```lua
  -- 'A' (65) — Arpeggiator
  if char == 65 then
      local arp = require("ui.piano-roll.arpeggiator")
      arp.HandleArpeggiator()
      return true
  end
  ```
- [ ] D.3.2 Place alongside other single-char tool shortcuts (Paint/Knife/Eraser), keeping same pattern

### D.4 — Implement `HandleArpeggiator()` in arpeggiator.lua

- [ ] D.4.1 In `src/ui/piano-roll/arpeggiator.lua`: add `HandleArpeggiator()` exported function
- [ ] D.4.2 Read notes + selected indices from `island_store`; no-op (return) if no selection
- [ ] D.4.3 Read `direction`, `speed_beats`, `pattern` from inline defaults (not from store per scope boundary)
- [ ] D.4.4 Call `GenerateArpeggio()` and capture `generated_uuids`, `generated_notes`
- [ ] D.4.5 Build `new_state` for undo: array of `{start_beat, duration, pitch, velocity, muted, uuid}` for each generated note
- [ ] D.4.6 Push `{type = "add", note_uuids = generated_uuids, new_state = new_state}` with `prev_state = nil` (standard "add" pattern, matching existing `"add"` branch in undo.lua)
- [ ] D.4.7 Call `note.MarkNotesDirty()` at end

### D.5 — Re-export from piano-roll barrel

- [ ] D.5.1 In `src/ui/piano-roll.lua`: add `local arpeggiator = require("ui.piano-roll.arpeggiator")` at the top
- [ ] D.5.2 Add `piano_roll.HandleArpeggiator = arpeggiator.HandleArpeggiator`
- [ ] D.5.3 No change to `piano-roll/interaction.lua` barrel needed — `shortcuts.HandleArpeggiator` would only be needed if interaction.lua re-exports shortcuts.HandleArpeggiator explicitly. Since shortcuts.lua dispatches inside its own `HandleKeyboardShortcut` (requires arpeggiator inline), the barrel in spreadsheet.lua alone is sufficient

### D.6 — Verify

- [ ] D.6.1 Manual: Select C Major chord (C4, E4, G4) starting at beat 1.0, press `A` — verify 3 new notes inserted: C4@1.0, E4@1.0625, G4@1.125 (Up, Staccato, 1/16)
- [ ] D.6.2 Manual: Same, Down direction — verify G4, E4, C4 order
- [ ] D.6.3 Manual: Ctrl+Z after arpeggiate — verify all generated notes removed in a single undo step
- [ ] D.6.4 Manual: No selection + `A` — verify no crash, no notes inserted
- [ ] D.6.5 Manual: Sustain pattern — verify generated note durations match original note durations (not speed_beats)

---

## Multi-Slice Cross-Cutting Checks

- [ ] X.1 After all 4 slices: run the test runner (`tests/AGENTS.md` runner entry point) — expect existing 497 assertions to still pass
- [ ] X.2 After Slice A: verify `quantize.QuantizeBeat()` still works as before (no regression in non-swing mode)
- [ ] X.3 After Slices B + C: Ctrl+H and Shift-drag velocity must not interfere — confirm Shift-drag priority when both held
- [ ] X.4 After Slice D: original chord notes must NOT be removed by arpeggiator (destructive addition only)

---

## Summary Table

| Slice | Feature | Files changed | Files added | Est. LOC |
|-------|---------|--------------|-------------|----------|
| A | Swing | `quantize.lua`, `header.lua`, `shortcuts.lua` | — | ~120 |
| B | Humanize | `island.lua`, `shortcuts.lua`, `undo.lua`, `piano-roll.lua` | `humanize.lua` (core), `humanize.lua` (ui) | ~180 |
| C | Velocity Edits | `velocity.lua`, `input.lua` | — | ~220 |
| D | Arpeggiator | `shortcuts.lua`, `piano-roll.lua` | `arpeggiator.lua` | ~240 |

**Total est. LOC changed: ~760**
**Chained PRs: Yes — 4 PRs (feature-branch-chain)**
