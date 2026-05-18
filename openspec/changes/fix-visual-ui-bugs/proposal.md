# Proposal: Fix Visual/UI Bugs

## Intent

Seven visual defects degrade the polish of the GROVE FL MIDI UI: pads lack playback progress indicators, velocity bar corners deform inconsistently between collapsed/expanded states, piano roll notes show bottom "valley" artifacts at small zoom, the timeline ruler flickers on scroll, and the vertical scrollbar thumb shrinks when velocity expands. These are all rendering-only bugs — no functional behavior changes.

## Scope

### In Scope
1. **Pad progress overlay** — Add playback progress bar to `pads.lua` matching `slots.lua` behavior
2. **Velocity corner radius consistency** — Fix `DrawRoundedRectEx` radius clamping in `velocity.lua` (collapsed h=10 → r=5 vs expanded r=10)
3. **Velocity/spine bottom-left corner alignment** — Fix spine post-fix in `midi-island.lua` line 338 when velocity is collapsed
4. **Piano roll note valley deformation** — Reduce/disable corner radius for narrow notes in `piano-roll/note.lua` when `nw < 8`
5. **Timeline ruler sub-pixel flicker** — Use `math.floor` on `scroll_x` tick positions in `timeline.lua` to eliminate 1px jitter
6. **Vertical scrollbar thumb ratio** — Include velocity height in `visible_rows` calculation in `midi-island.lua` `DrawScrollbars`

### Out of Scope
- Functional changes to pad interaction, velocity editing, or scrollbar behavior
- Compact panel rendering (these bugs affect full mode only)
- New features or spec-level behavior changes

## Capabilities

### New Capabilities
None

### Modified Capabilities
- `piano-roll`: Note rendering corner radius behavior for narrow notes; scrollbar thumb ratio calculation
- `velocity-editor`: Corner radius consistency across collapsed/expanded states
- `timeline-ruler`: Sub-pixel scroll jitter elimination
- `ui`: Pad progress overlay during playback; spine corner alignment with velocity panel

## Approach

| # | Bug | File | Fix |
|---|-----|------|-----|
| 1-2 | Pads missing progress | `src/ui/pads.lua` | Add progress overlay mirroring `slots.lua` lines 64-68: read `sequencer_store.GetProgress()` + `GetCurrentStep()`, draw proportional `DrawRoundedRect` when pad's degree matches current playing step |
| 3 | Velocity corner mismatch | `src/ui/velocity.lua` line 131 | Use dynamic `r = math.min(10, h/2)` so collapsed (h=10) gets r=5 consistently; or use fixed r=5 for both states |
| 4 | Spine bottom-left corner | `src/ui/midi-island.lua` line 338 | When velocity collapsed, spine post-fix rect should extend from piano-roll bottom (not velocity bottom) or use square corner instead of rounded |
| 5 | Note valley at small zoom | `src/ui/piano-roll/note.lua` | In `DrawNoteWithGradient`, compute `r = nw < 8 and 0 or 3` (and same for muted path at line 68, selected border at line 120, ghost at line 190) |
| 6 | Timeline flicker | `src/ui/timeline.lua` line 51 | Change `bx = x + (beat - scroll_x) * zoom_x` to use `math.floor(scroll_x)` for tick position computation, matching `beat_start` logic at line 42 |
| 7 | Scrollbar shrinks | `src/ui/midi-island.lua` line 402 | Change `vsb_h = pr_h + ve_h` to track correctly; change `visible_rows` to `(pr_h + ve_h) / PITCH_ROW_H` so thumb ratio accounts for full scrollable area |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/ui/pads.lua` | Modified | Add playback progress overlay per pad during sequencer playback |
| `src/ui/velocity.lua` | Modified | Fix corner radius to be consistent across collapsed/expanded states |
| `src/ui/midi-island.lua` | Modified | Fix spine post-fix corner + fix vertical scrollbar thumb ratio |
| `src/ui/piano-roll/note.lua` | Modified | Reduce corner radius for narrow notes (nw < 8) |
| `src/ui/timeline.lua` | Modified | Use floored scroll_x for tick positions to eliminate sub-pixel jitter |
| `openspec/specs/piano-roll/spec.md` | Modified | Add requirement: corner radius adapts to note width |
| `openspec/specs/velocity-editor/spec.md` | Modified | Add requirement: corner radius consistent across states |
| `openspec/specs/timeline-ruler/spec.md` | Modified | Add requirement: tick positions stable during smooth scroll |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Pad progress overlay adds per-frame `sequencer_store` reads | Low | Already called in slots; sequencer_store is a simple state read |
| Corner radius change alters pad visual identity | Low | Progress overlay is additive; base pad rendering unchanged |
| Note radius=0 for small notes looks square | Medium | Only triggers at `nw < 8` (extreme zoom-out); acceptable tradeoff vs valley artifact |
| Timeline floor() shifts tick alignment by <1px | Low | Sub-pixel shift is imperceptible; eliminates visible flicker |
| Scrollbar thumb ratio change affects drag feel | Low | Thumb gets larger (more accurate), not smaller; drag math unchanged |

## Rollback Plan

Revert all 5 modified files via `git checkout`:
```
git checkout HEAD -- src/ui/pads.lua src/ui/velocity.lua src/ui/midi-island.lua src/ui/piano-roll/note.lua src/ui/timeline.lua
```
No state migrations, no config changes, no database changes. Pure rendering fixes — safe to revert at any time.

## Dependencies

None. All fixes are self-contained within existing modules. No new dependencies or external libraries.

## Success Criteria

- [ ] Pads show a progress overlay when their degree matches the current sequencer step during playback
- [ ] Velocity bar bottom-right corner radius is identical in collapsed (10px) and expanded (100px) states
- [ ] Spine bottom-left corner aligns cleanly with velocity background when velocity is collapsed
- [ ] Piano roll notes at extreme zoom-out (nw < 8px) render without bottom valley deformation
- [ ] Timeline ruler measure labels do not flicker or skip during smooth scroll
- [ ] Vertical scrollbar thumb size remains stable when velocity panel expands/collapses
- [ ] No new GFX artifacts, crashes, or performance regressions
