## Verification Report

**Change**: window-repositioning-fix
**Version**: N/A (no formal spec artifact — proposal serves as spec)
**Mode**: Standard

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | 10 (4 code + 6 manual verification) |
| Tasks complete | 4 (all code tasks) |
| Tasks incomplete | 6 (manual — require REAPER runtime) |

### Build & Tests Execution
**Build**: ➖ Not applicable (Lua script, no build step)
**Tests**: ➖ Not available (REAPER Lua — no test infrastructure)
**Coverage**: ➖ Not available

### Spec Compliance Matrix
Proposal success criteria mapped to implementation evidence:

| Requirement | Scenario | Implementation | Result |
|-------------|----------|----------------|--------|
| Window stable on MIDI Island toggle | expand/collapse | gfx-window.lua:41-42 → RecreateMainWindow(720, new_h, ox, oy, 0) | ✅ COMPLIANT |
| Window stable on size enforcement | min bounds resize | main.lua:373 → RecreateMainWindow(720, min_h, ox, oy, 0) | ✅ COMPLIANT |
| Window stable on COMPACT↔FULL | mode switch | compact-init.lua:97 → RecreateMainWindow(gs.w, gs.h, gs.x, gs.y, gs.dock) | ✅ COMPLIANT |
| JS_Window_SetPosition missing → silent | API unavailable | gfx-safe.lua:63 → CheckAPI("JS_Window_SetPosition") guard + pcall | ✅ COMPLIANT |
| No docked mode regression | docked window | dock=0 passed for main/gfx-window; gs.dock for compact-init | ✅ COMPLIANT |
| All 3 sites use RecreateMainWindow | no inline patterns | Source inspection confirmed; zero remaining gfx.quit()+gfx.init() inline pairs | ✅ COMPLIANT |

**Compliance summary**: 6/6 scenarios compliant

### Correctness (Static Evidence)
| Requirement | Status | Notes |
|------------|--------|-------|
| Position capture before gfx.quit() | ✅ Implemented | gfx-safe.lua:38-42 — JS_Window_GetRect with safety clamp (l > -10000, l < 10000), falls back to (x,y) if hwnd nil |
| gfx.quit()+gfx.init() in pcall | ✅ Implemented | gfx-safe.lua:52-56 — pcall wraps the full recreation sequence |
| JS_Window_SetPosition force | ✅ Implemented | gfx-safe.lua:63-65 — CheckAPI + gfx.hwnd guard + pcall |
| Graceful fallback chain | ✅ Implemented | 3 levels: HWND nil → fallback (x,y); API missing → skip; SetPosition error → pcall |
| Unique temp title (gfx.ini cache bypass) | ✅ Implemented | gfx-safe.lua:49 — `config.script_title .. reaper.time_precise()` |
| Title restoration after recreation | ✅ Implemented | gfx-safe.lua:68-69 — JS_Window_SetTitle |
| Position persistence to ExtState | ✅ Implemented | gfx-safe.lua:73-74 — persist.Save("view_offset_x/y", pos) |
| gfx.setfont after gfx.init | ✅ Implemented | gfx-safe.lua:55 — gfx.setfont(1, "Calibri", 16) |
| last_gfx_state mutation removed from gfx-window | ✅ Implemented | No compact_store/persist/config requires remain in gfx-window.lua |
| dock param correctly forwarded | ✅ Implemented | gfx-safe.lua:33 — dock defaults to 0; all 3 call sites pass appropriate dock value |
| All requires correct | ✅ Implemented | gfx_safe required in all 3 consumer files; gfx-safe.lua requires config, api_guard, ui_store, persist — all exist at runtime |

### Coherence (Design)
Proposal decisions checked against implementation:

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Create RecreateMainWindow() in gfx-safe.lua | ✅ Yes | Lines 32-77 — single helper with position capture, recreate, force position, title restore |
| Replace inline gfx.quit()+gfx.init() at 3 sites | ✅ Yes | All 3 call sites confirmed |
| Guard JS_Window_SetPosition with CheckAPI + pcall | ✅ Yes | Lines 63-65: both guards present |
| Remove duplicated position-capture from call sites | ✅ Yes | gfx-window.lua no longer captures/caches position independently |
| Dock parameter forwarding | ✅ Yes | compact-init passes gs.dock; others pass 0 |

### Issues Found

**CRITICAL**: None
**WARNING**: None
**SUGGESTION**: None

### Verdict
**PASS**
All 4 code implementation tasks verified as correct through source inspection. 6 manual verification tasks (3.1-3.6) remain for user to confirm in REAPER runtime — these cannot be verified without the REAPER GFX environment. All proposal success criteria are structurally compliant.
