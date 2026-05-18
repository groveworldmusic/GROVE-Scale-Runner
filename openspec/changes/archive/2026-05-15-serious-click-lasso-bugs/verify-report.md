# Verify Report: serious-click-lasso-bugs

**Change**: serious-click-lasso-bugs
**Version**: spec v1 (delta), design v1
**Mode**: Standard (no strict TDD)
**Date**: 2026-05-13

---

## Verification Results

| Criteria | Status | Evidence |
|----------|--------|----------|
| **S1: Guard after finalization** | ✅ PASS | Lines 541–565 (finalization) → lines 567–572 (stale guard). Guard is AFTER the finalization block. |
| **S1: Guard still EXISTS** | ✅ PASS | Lines 567–572. The stale guard block was moved but NOT deleted. |
| **S1: Guard checks `lasso_active AND (cap&1)==0`** | ✅ PASS | Line 570: `if island_store.GetLassoActive() and (gfx.mouse_cap & 1) == 0 then` |
| **S1: selected_indices set BEFORE guard** | ✅ PASS | Line 558: `SetSelectedIndices(sel)` → Line 559: `SetLassoActive(false)` → Line 570: guard check (lasso already false, guard is no-op in normal flow) |
| **S2: Lasso dirty flag exists** | ✅ PASS | Line 279: `if island_store.GetLassoActive() then gfx_needs_redraw = true end` |
| **S2: Correct placement** | ✅ PASS | After line 278 (`PageOverrideTimer` check), before line 281 (`prev_dock`). Per design spec. |
| **S3: fresh_click bitmask** | ✅ PASS | Line 265: `(ui_store.GetLastMouseCap() & 1) == 0` — uses bitwise AND, not equality. |
| **S4: 675 tests pass** | ✅ PASS | `lua tests/run.lua` → 675 passed, 0 failed. Consume lifecycle tests pass. |
| **S4: Consume in views.lua (9 sites)** | ✅ PASS | Lines 349 (VEL), 374 (PLAY/STOP), 429 (MIDI toggle), 470 (volume slider), 549 (prev), 568 (next), 660 (docked VEL), 680 (docked PLAY/STOP), 703 (docked UNDOCK). All present. |
| **S4: Consume in pads.lua** | ✅ PASS | Line 147: `ui_store.ConsumeMouseClick()` after `midi.TriggerChord()`. |
| **S4: Consume in piano.lua** | ✅ PASS | Line 177: `ui_store.ConsumeMouseClick()` after `preferences_store.SetRootIndex()`. |
| **S4: Consume in dropdown.lua** | ✅ PASS | Line 77: `ui_store.ConsumeMouseClick()` after `gfx.showmenu()`. |
| **S4: Consume in paginator.lua** | ✅ PASS | Line 41: `ui_store.ConsumeMouseClick()` after `SetCurrentPage(i)`. |
| **Static: No consume in icon handlers** | ✅ PASS | `icons.lua:105` already consumes internally. CLEAR (view:391) and EXPORT (view:404) use `DrawToolIcon` which consumes via icons.lua. No double-consume. |
| **Static: No consume in PressOverlay** | ✅ PASS | All 5 PressOverlay calls (view:338, 359, 389, 403, 418) are consume-free. They're visual-only, paired with action handlers that do consume. |
| **Static: Stale guard exists** | ✅ PASS | Guard is at lines 567–572. Moved, not deleted. |

---

## Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 9 (1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1–3.5, 3.6) |
| Tasks complete (code) | 9/9 |
| Tasks verified | 9/9 |
| Tasks incomplete | 0 |

---

## Build & Tests Execution

**Tests**: ✅ 675 passed, 0 failed
```text
=== ALL TESTS PASSED ===
Passed: 675
Failed: 0
```

---

## Spec Compliance Matrix

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| S1: Lasso finalization order | Mouse-up computes selection before clearing | Static verification: Lines 544–558 compute `GetNotesInRect` → `SetSelectedIndices` before `SetLassoActive(false)`. | ✅ COMPLIANT |
| S1: Lasso finalization order | Alt-tab while dragging | Static verification: Guard at line 570 clears state if finalization didn't (defensive). Notes ARE selected on alt-tab return (finalization fires with `cap&1==0`). No stuck state. | ✅ COMPLIANT (better than spec — lasso finalizes on return) |
| S2: Lasso dirty flag | Lasso rect updates during drag | Line 279 triggers redraw when `GetLassoActive()`. Verified via grep. | ✅ COMPLIANT |
| S2: Lasso dirty flag | No lasso — no extra redraw | `GetLassoActive()` returns false → flag is not set. | ✅ COMPLIANT |
| S3: fresh_click bitmask | Right-click held then left-click | Line 265: `(ui_store.GetLastMouseCap() & 1) == 0`. With cap=2→3: `(2&1)==0=true`. | ✅ COMPLIANT |
| S3: fresh_click bitmask | Normal click unchanged | With cap=0→1: `(0&1)==0=true`. Identical behavior. | ✅ COMPLIANT |
| S4: Click consumption | Click consumed by dropdown | dropdown.lua:77 consumes after `gfx.showmenu()`. | ✅ COMPLIANT |
| S4: Click consumption | No click — no consume | All consume calls are nested inside `if GetMouseClick()` blocks. | ✅ COMPLIANT |

**Compliance summary**: 8/8 scenarios compliant

---

## Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| S1: Stale guard reordered after finalization | ✅ Implemented | Guard moved from original position (~line 215) to after finalization block (lines 567–572) |
| S2: Lasso dirty flag in MainLoop | ✅ Implemented | `if island_store.GetLassoActive() then gfx_needs_redraw = true end` at line 279 |
| S3: fresh_click bitwise AND | ✅ Implemented | `(ui_store.GetLastMouseCap() & 1) == 0` at line 265 |
| S4: ConsumeMouseClick in all 5 files | ✅ Implemented | 13 consume calls added across views.lua, pads.lua, piano.lua, dropdown.lua, paginator.lua |
| S4: No consume in PressOverlay-only sites | ✅ Implemented | All PressOverlay calls are consume-free |
| S4: No double-consume via DrawToolIcon | ✅ Implemented | icons.lua:105 handles consume; CLEAR/EXPORT consumers don't add extra |

---

## Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Move stale guard to after finalization | ✅ Yes | Lines 567–572 (after line 565). Exact match. |
| Add lasso dirty flag after PageOverrideTimer | ✅ Yes | Line 279, after line 278, before line 281. |
| Change `== 0` to `& 1) == 0` | ✅ Yes | Line 265. Exact match. |
| Add Consume to 9 views.lua sites | ✅ Yes | All 9 sites confirmed. Line numbers shifted slightly from design due to normal code evolution. |
| Add Consume to pads.lua (141→147) | ✅ Yes | Line 147. Content matches. |
| Add Consume to piano.lua (163→177) | ✅ Yes | Line 177. Content matches. |
| Add Consume to dropdown.lua (65→77) | ✅ Yes | Line 77. Content matches. |
| Add Consume to paginator.lua (39→41) | ✅ Yes | Line 41. Content matches. |
| Do NOT add consume to PressOverlay-only | ✅ Yes | 0 consume calls in PressOverlay blocks. |
| Do NOT add consume to DrawToolIcon callers | ✅ Yes | CLEAR (line 391) and EXPORT (line 404) use DrawToolIcon; no extra consume. |

---

## Issues Found

**CRITICAL**: None

**WARNING**: None

**SUGGESTION**: 
- The MIDI CH button (`midi-island.lua:248`) and PRESETS button (`midi-island.lua:272`) use `GetMouseClick()` with `gfx.showmenu()` but do NOT call `ConsumeMouseClick()`. This was explicitly out of scope for S4. If these buttons ever overlap with other widgets in the render order, they could cause double-fire. Recommend addressing in a follow-up if layout changes occur.

---

## Verdict

**PASS** ✅

All four fixes (S1–S4) are correctly implemented. The stale guard is properly positioned after lasso finalization, the dirty flag forces redraw during lasso drag, the `fresh_click` bitmask correctly handles right-click-held scenarios, and `ConsumeMouseClick()` is properly placed in all 13 handler sites across 5 files. All 675 tests pass. No regressions detected.
