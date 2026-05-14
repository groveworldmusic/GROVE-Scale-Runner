# Design: distribution-prep

## Technical Approach

**Fundamental discovery**: every artifact the proposal assumed as "new" already exists in the codebase — ReaPack header tags (`@donation`, `@links`, `@website`), config constants (`APP_NAME`, `APP_VERSION`, `DONATION_URL`), CI workflow (`.github/workflows/reapack-index.yml`), `.reapack-index.yaml`, and `README.md`. The change shifts from **create** to **normalize & verify**: the primary work is resolving brand inconsistency between `@author`, SPDX copyright, and `APP_NAME`, then auditing existing infrastructure.

**What remains to create**: nothing. All 5 proposal items (header tags, config constants, README, CI, branding) are pre-existing.

## Architecture Decisions

### Decision: `@author` value

| Option | Trade-off | Decision |
|--------|-----------|----------|
| `@author Andrik on the beat` | Matches SPDX; mixes artist alias with credit | No |
| `@author GROVE WORLD MUSIC` | Matches current header; legal entity but vague | No |
| `@author Andrik Sanz Cordoví` | Real name for professional ReaPack credit | **Chosen** |

**Rationale**: `@author` in ReaPack metadata is attribution — real name is standard practice. SPDX copyright retains the pseudonym `Andrik on the beat` which is fine for copyright (legal entity vs artistic alias are different concerns). `APP_NAME = "GROVE Scale Runner"` is the product name. Three distinct roles: product identity, copyright holder, author credit.

### Decision: README treatment

| Option | Trade-off | Decision |
|--------|-----------|----------|
| Full rewrite | Risk of losing good existing content | No |
| Iterative update | Lower risk, preserves solid content | **Chosen** |

**Rationale**: Existing README is already well-structured (features, install, usage, license, Ko-fi button). Only needs credit normalization and URL review.

## Data Flow

No runtime data flow changes. All changes are static metadata/files — zero code paths modified.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/main.lua:5` | Update | `@author GROVE WORLD MUSIC` → `@author Andrik Sanz Cordoví` |
| `src/main.lua:2` | Verify | SPDX `Andrik on the beat` — confirm pseudonym is intentional |
| `src/main.lua:72-74` | Update | Changelog: append brand normalization entry |
| `src/config.lua:9` | Verify | `EXTSTATE_NS = "GROVE_Scale_Runner"` — confirm consistent with `APP_NAME` |
| `README.md` | Update | Normalize credit lines; verify installation URLs match repo |
| `.github/workflows/reapack-index.yml` | Verify | Confirm workflow works for public repo (push to main triggers index) |
| `.reapack-index.yaml` | Verify | Confirm `index-version: '1.2.0'` is sufficient for current reapack-index |

**No new files created.** No files deleted.

## Interfaces / Contracts

No new interfaces. Current ReaPack header is fully compliant:

```lua
-- @donation https://ko-fi.com/groveworldmusic
-- @links
--   Donaciones https://ko-fi.com/groveworldmusic
--   GitHub https://github.com/GroveWorldMusic/GROVE-Scale-Runner
-- @website https://github.com/GroveWorldMusic/GROVE-Scale-Runner
```

Only `@author` changes. Tag set is complete.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | `@author` matches expected value | Grep assert |
| Static | SPDX year is 2026 | Grep assert |
| Verification | No regressions | All 497 existing tests pass unchanged |

## Migration / Rollout

No migration required. All changes are additive or cosmetic. Rollback: revert `main.lua:5`, revert README credits via `git checkout`.

## Open Questions

- [ ] Confirm: is `Andrik on the beat` the intended pseudonym for SPDX copyright, or should it be the legal name?
- [ ] Confirm: Ko-fi username `groveworldmusic` is correct and active?
- [ ] Confirm: `@links` should use Spanish labels (`Donaciones`) or switch to English (`Donations`)?
