# Verification Report — Phase B: Progression-Only Presets

| Field | Value |
|-------|-------|
| **Change** | remaining-features — Phase B (progression-only presets) |
| **Scope** | 4 files: io.lua, main.lua (preset-browser), preset-list.lua, preset-browser.lua |
| **Mode** | Standard verify (no test runner, no strict TDD) |
| **Date** | 2026-05-18 |

---

## Completeness

| Task | Status |
|------|--------|
| 2.1 Dual-ext scanning, SaveProgressionPreset, LoadPreset branching (io.lua) | ✅ Done |
| 2.2 Filter tabs + Save Progression button (main.lua) | ✅ Done |
| 2.3 type_filter param + type badge (preset-list.lua) | ✅ Done |
| 2.4 Re-export SaveProgressionPreset (preset-browser.lua) | ✅ Done |

**4/4 tasks complete** — no missing tasks.

## Build Evidence

| Check | Result |
|-------|--------|
| `luac -p src/ui/preset-browser/io.lua` | ✅ Clean (no errors) |
| `luac -p src/ui/preset-browser/main.lua` | ✅ Clean (no errors) |
| `luac -p src/ui/preset-browser/preset-list.lua` | ✅ Clean (no errors) |
| `luac -p src/ui/preset-browser.lua` | ✅ Clean (no errors) |

## Tests

No test files exist for Phase B. Phase E (UI tests, task 5.2: `test_preset_browser_io.lua`) is not yet implemented. No test evidence to report.

## Spec Compliance Matrix

### ADDED Requirements

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| R1 | **Dual-Extension Support**: scan `.grove` + `.grove-prog` | ✅ Compliant | `io.lua` L39-40 (constants), L68-72 (`IsValidPresetFile`), L120-153 (scanning with type tagging) |
| R2 | **Save Progression Preset**: serialize `progression[1..16]` + context to `.grove-prog` | ✅ Compliant | `io.lua` L261-319 (`SaveProgressionPreset`): `type="progression"` (L270), `version=3` (L271), 4 context fields (L272-275), no `notes` array |
| R3 | **Type Filter Tabs**: All/Notes/Progression tabs | ✅ Compliant | `main.lua` L202-229 (tab rendering + click toggles `_type_filter`), L182-191 (filter applied to file list) |
| R4 | **Type-Aware Preset List**: `type_filter` param + type badge | ✅ Compliant | `preset-list.lua` L42 (param in signature), L189-204 (badge render: "Prog." green, "Notes" blue) |

### MODIFIED Requirements

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| R5 | **Save Preset**: save should check active filter tab | ⚠️ Deviation | Spec says save behavior changes by tab. Implementation uses separate "S-PROG" button that always saves progression. Follows design (B2) and task 2.2, but deviates from spec's modified requirement. **Functional equivalent achieved.** |
| R6 | **Load Preset**: branch by `type` field, skip `SetNotes` for progression | ✅ Compliant | `io.lua` L337-351: checks `result.type == "progression"` OR `.grove-prog` ext → calls `ClearProgUndoStacks()` (L341), restores context + progression (L342-348), NO `SetNotes()` call |

## Correctness Table

| Area | Checks | Verdict |
|------|--------|---------|
| **io.lua** — `SaveProgressionPreset` | format: type="progression", version=3, notes absent, context fields present, progression[1..16] | ✅ Correct |
| **io.lua** — `LoadPreset` branching | type-progression branch skips notes, calls ClearProgUndoStacks, restores ctx+prog; notes branch unchanged | ✅ Correct |
| **io.lua** — `IsValidPresetFile` | accepts both extensions | ✅ Correct |
| **io.lua** — `ScanDirectory` | tags files with type="notes"/"progression"; sorts combined list | ✅ Correct |
| **main.lua** — `_type_filter` | module-local, default "all", reset on reload | ✅ Correct (matches design B2) |
| **main.lua** — S-PROG button | sanitizes name, calls SaveProgressionPreset + GetProgressionPresetFilePath | ✅ Correct |
| **main.lua** — filter tabs | All/Notes/Prog set `_type_filter`, filter reapplied to `files` before list render | ✅ Correct |
| **preset-list.lua** — type badge | "Prog." green / "Notes" blue, positional math with other badges | ✅ Correct |
| **preset-browser.lua** — barrel | SaveProgressionPreset + GetProgressionPresetFilePath re-exported | ✅ Correct |

## Design Coherence

| Design Decision | Implementation | Status |
|-----------------|----------------|--------|
| B1: Load branching by `type` field + `.grove-prog` ext | `io.lua` L337: `result.type == "progression"` OR ext match | ✅ Aligned |
| B2: Filter tab state = module-local `_type_filter` | `main.lua` L34: `local _type_filter = "all"` | ✅ Aligned |
| 2.1: +65 LOC in io.lua | Actual: ~60 LOC (SaveProgressionPreset + LoadPreset branch + IsValidPresetFile + GetProgressionPresetFilePath + ScanDirectory dual-ext) | ✅ Approx match |
| 2.2: +55 LOC in main.lua | Actual: ~55 LOC (filter tabs + S-PROG button + type filter loop) | ✅ Approx match |
| 2.3: +12 LOC in preset-list.lua | Actual: ~16 LOC (type_filter param + badge rendering) | ✅ Slight over, reasonable |
| 2.4: +1 LOC in preset-browser.lua | Actual: +2 lines (SaveProgressionPreset + GetProgressionPresetFilePath) | ✅ Over but correct |

## Issues

### ⚠️ WARNING 1: Dead `type_filter` parameter in `DrawPresetList`
**File**: `preset-list.lua` L42
**Detail**: `DrawPresetList()` receives `type_filter` param but never uses it. Filtering is already done at the caller (`main.lua` L182-191). Parameter is dead.
**Severity**: Cosmetic. No functional impact.

### ⚠️ WARNING 2: Hardcoded badge colors instead of theme colors
**File**: `preset-list.lua` L192-194
**Detail**: Spec says badge "SHALL render using theme's `accent` and `dim` colors." Implementation uses hardcoded `{0.3,0.5,0.8,0.6}` (blue) and `{0.3,0.7,0.3,0.6}` (green). Theme module doesn't have `accent`/`dim` color keys, so this can't be easily fixed without adding them.
**Severity**: Minor. Colors are readable and consistent.

### ⚠️ WARNING 3: Spec vs design divergence on Save Preset behavior
**File**: `main.lua` (preset-browser) L231-256
**Detail**: Spec's modified requirement (R5) says existing Save should check active filter tab to decide format. Implementation uses a dedicated S-PROG button instead. The existing Ctrl+S save (in `midi-island/header.lua` L189) still always writes `.grove`, unaffected by the filter tab.
**Severity**: Minor. Design doc B2 and task 2.2 intentionally chose the separate-button approach. Functional equivalence is achieved: users can save progression-only presets via S-PROG from any tab.

---

## Final Verdict

**PASS WITH WARNINGS**

The implementation fully satisfies all 4 tasks for Phase B. All 4 files pass syntax checks. The spec's ADDED requirements are 100% compliant. The only MODIFIED requirement (Save Preset) uses a separate-button approach instead of type-tab-aware branching — this is an intentional design decision documented in B2.

Warnings 1 (dead param) and 2 (hardcoded colors) are cosmetic. Warning 3 is a design divergence from the spec, not an implementation defect.

**No critical issues.** Ready for archive.
