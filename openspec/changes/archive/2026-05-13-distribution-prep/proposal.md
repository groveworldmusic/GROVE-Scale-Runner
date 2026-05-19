# Proposal: distribution-prep

## Intent

Add missing distribution infrastructure (ReaPack donation metadata, README, GitHub Actions, donation link, branding consistency) so the project is ready for professional ReaPack + GitHub publishing.

## Scope

**In scope:**
1. `@donation` + `@links` tags in `main.lua` ReaPack header
2. `config.APP_VERSION` + `config.DONATION_URL` in `config.lua`
3. `README.md` at project root (features, install, links)
4. ReaPack `index.xml` generation via GitHub Actions
5. `.github/workflows/reapack-index.yml` CI workflow
6. Normalize `@author` vs `APP_NAME` vs SPDX copyright branding

**Out of scope:** "About" dialog, first-run onboarding, DEBUG flag, UTF-8 handling, hardcoded `\\` paths (separate cross-platform fix).

## Capabilities

### New Capabilities
- `distribution-packaging`: ReaPack tags, index.xml, GitHub Actions CI, donation URL
- `project-presentation`: README.md, branding consistency

### Modified Capabilities
None.

## Approach

| Item | Approach |
|------|----------|
| Header tags | 2 comment lines after `@changelog` in `main.lua` |
| Constants | `config.APP_VERSION = "1.0.0"` + `config.DONATION_URL = "https://ko-fi.com/groveworldmusic"` in `config.lua` |
| README | New file: description, features, install, usage, GitHub + Ko-fi links |
| ReaPack index | `reapack-index` CLI in CI; `.reapack-index.yaml` config |
| GitHub Actions | Standard yml: checkout → reapack-index → commit index.xml |
| Branding | Propose: `@author Andrik on the beat` + `APP_NAME = "GROVE Scale Runner"` - confirm before merge |

## Affected Areas

| Area | Impact |
|------|--------|
| `src/main.lua` | Modified (+2 header lines) |
| `src/config.lua` | Modified (+2 constants) |
| `README.md` | **New** |
| `.github/workflows/reapack-index.yml` | **New** |
| `.reapack-index.yaml` | **New** |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Ko-fi username unconfirmed | High | Placeholder; flag for user |
| Brand identity unclear | Med | Separate artist (`@author`) from product (`APP_NAME`) |
| `reapack-index` CI availability | Low | Use `npx reapack-index` |

## Rollback Plan

Revert 2 header lines in `main.lua`, remove 2 constants in `config.lua`, delete `README.md`, delete `.github/` workflow files. Additive metadata — no migration needed.

## Dependencies

- `reapack-index` npm package (CI index generation)
- Ko-fi account (confirm donation URL)

## Success Criteria

- [ ] `main.lua` grep shows `@donation` and `@links`
- [ ] `config.lua` exports `APP_VERSION` and `DONATION_URL`
- [ ] `README.md` exists with features, install, and links
- [ ] `.github/workflows/reapack-index.yml` is valid YAML
- [ ] No regressions: all 497 tests pass unchanged
- [ ] Branding is consistent across all headers (no contradictions)
