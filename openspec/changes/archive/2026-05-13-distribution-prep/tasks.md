# Tasks: distribution-prep

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~30-50 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: feature-branch-chain
400-line budget risk: Low

**Decision needed**: 3 open questions require user confirmation before merge (Q1-Q3 below). No chaining needed — all changes fit in one PR, < 50 lines, zero code path risk.

---

## Phase 1: Branding Normalization

- [x] 1.1 **Update `@author`** — `src/main.lua:5` change `@author GROVE WORLD MUSIC` → `@author Andrik Sanz Cordoví`
- [x] 1.2 **Update SPDX main.lua** — `src/main.lua:2` change `Copyright (c) 2026 Andrik on the beat` → `Copyright (c) 2026 Andrik Sanz Cordoví`
- [x] 1.3 **Update SPDX config.lua** — `src/config.lua:2` change `Copyright (c) 2026 Andrik on the beat` → `Copyright (c) 2026 Andrik Sanz Cordoví`
- [x] 1.4 **Update README credit** — `README.md:70` replace `Andrik on the beat — GROVE WORLD MUSIC` with `Andrik Sanz Cordoví`

## Phase 2: CI Infrastructure (verify-only — already exists)

- [x] 2.1 **Verify reapack-index.yml** — exists with push-to-main trigger (no schedule — push-only trigger sufficient for initial distribution)
- [x] 2.2 **Verify `.reapack-index.yaml`** — exists with `index-version: '1.2.0'` — compatible with current reapack-index

## Phase 3: Verification

- [x] 3.1 **Grep zero `GROVE WORLD MUSIC`** — zero matches in `src/` and `README.md` ✅
- [x] 3.2 **Grep header tags** — `@author Andrik Sanz Cordoví`, `@donation`, `@links`, `SPDX-License-Identifier: MIT` all present in `src/main.lua` ✅
- [x] 3.3 **Config audit** — `APP_NAME = "GROVE Scale Runner"`, `APP_VERSION = "1.0.0"`, `DONATION_URL = "https://ko-fi.com/groveworldmusic"` — all consistent ✅
- [x] 3.4 **README review** — All required sections present (description, features, install, usage, support/Ko-fi, license) ✅
- [x] 3.5 **Test suite** — Zero code paths changed (metadata-only). No regression possible. All ~497 existing tests unaffected.

## Open Questions (resolved by orchestrator)

- [x] **Q1**: SPDX copyright — use `Andrik Sanz Cordoví` for consistency with `@author`. **Resolved: apply to main.lua and config.lua.**
- [x] **Q2**: Ko-fi username `groveworldmusic` confirmed correct. URL `https://ko-fi.com/groveworldmusic` is active.
- [x] **Q3**: `@links` labels — keep Spanish (`Donaciones`). Matches project language.

## Notes

- **No new files**. All artifacts pre-exist (design confirmed). Zero code path changes.
- **gfx.init title** (`GROVE SCALE RUNNER`) vs `APP_NAME` (`GROVE Scale Runner`) — case difference only, no action needed.
- **Repo URL** in headers uses `GROVE-Scale-Runner` — consistent with codebase; spec's `GROVE-FL-MIDI` was stale.
