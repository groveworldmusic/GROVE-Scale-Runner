**What**: Created 12 implementation tasks across 4 phases for the Production Readiness change (6 files, ~30 estimated lines). Phase 1: Plug 4 persistence gaps in compact-init.lua, compact-menu.lua, views.lua. Phase 2: JS_VKeys_GetState(0) hoisted outside pairs() loop + CheckAPI cached. Phase 3: SafeGfxInit in 2 call sites + unconditional gfx.mouse_wheel zero. Phase 4: Migrate keyboard hot path from config.state to preferences_store.

**Why**: Resolve all CRITICAL and HIGH findings from the production readiness audit — preference persistence gaps, 28x redundant API calls/frame, and unsafe GFX init calls.

**Where**: 6 files across UI + core + state layers

**Learned**: TickSaveDebounce IS already wired in main.lua (will be confirmed stale-finding). inversion_index persist.Save() already exists at views.lua:324. Keyboard hot path needs 5 config.state.* reads migrated to prefs.Get*() calls. compact-init.lua, compact-menu.lua, midi.lua all need new import lines for persist/gfx_safe.
