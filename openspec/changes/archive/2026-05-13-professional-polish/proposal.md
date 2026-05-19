# Proposal: Professional Polish

## Intent

Complete gaps after `production-ready-polish` (archived): incomplete ReaPack metadata, zero defensive guards on REAPER API calls, no licensing/docs infrastructure.

## Scope

**In**: A) ReaPack — `@provides` completeness (46 files), `@changelog`, naming consistency, LICENSE. B) Defensive — undo blocks on ExportToMidi, `APIExists()` on JS\_\* APIs, nil guards on key `reaper.*` returns, bounds-clamping `config.state.*_index`, dirty-flag on MainLoop, expand `ValidatePtr()`. C) Docs — license headers on 46 files, `CHANGELOG.md` + `CONTRIBUTING.md` in root, section comment conventions.

**Out**: Cross-platform portability — deferred to separate change.

## Capabilities

### New / Modified Capabilities
None — all changes are code-quality / packaging level, no spec-level behavioral change.

## Approach

| Area | Approach |
|------|----------|
| A | Scripted audit vs `dir src/*.lua`. Add `@changelog`. Standardize naming. MIT `LICENSE`. |
| B | Undo blocks around ExportToMidi. `APIExists()` guard per JS\_\* call. Nil checks on optional returns. Clamp indices before array access. Frame-skip MainLoop on dirty flag. `ValidatePtr()` on all persistent refs. |
| C | Template header across all files. Root docs. Section-comment convention in AGENTS.md. |

## Affected Areas

| Area | Change |
|------|--------|
| `src/main.lua` | `@provides`, `@changelog`, dirty-flag, header |
| `src/core/` (3 files) | Undo blocks, API/nil guards, ValidatePtr |
| `src/ui/` (25 files) | Headers, section comments, nil guards |
| `src/state/` (6 files) | Headers, bounds checks |
| `src/config.lua` | Bounds-clamping helpers |
| Root | `LICENSE`, `CHANGELOG.md`, `CONTRIBUTING.md` |

## Risks

| Risk | Mitigation |
|------|------------|
| Dirty-flag stale render | Skip only `gfx.update`; always run logic |
| Undo block too wide | Single pair around project mutation only |
| Header mismatch | Single MIT template, automated apply |

## Rollback

Independent revert per area (A/B/C). Root docs deleted on C revert, headers restored from parent commit.

## Dependencies

Prior `production-ready-polish` outputs (already in codebase).

## Success Criteria

- [ ] `@provides` = 46 files (`dir src/*.lua /s /b \| measure`).
- [ ] `Undo_BeginBlock` present. All JS\_\* calls have `APIExists` guard.
- [ ] Listed `reaper.*` calls have nil guards. `ValidatePtr` on all persistent refs.
- [ ] All 46 `.lua` files carry license header.
- [ ] `LICENSE`, `CHANGELOG.md`, `CONTRIBUTING.md` exist in root.
