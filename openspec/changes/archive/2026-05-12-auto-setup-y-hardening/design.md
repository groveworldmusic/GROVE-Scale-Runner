# Design: Auto Setup y Hardening

## Technical Approach

Two independent concerns in one change: auto-track-setup (new capability) + 6 bug fixes. Each fix is minimal and isolated to its module. Auto-setup runs once at startup after consent, gated by ExtState so it never repeats unbidden.

## Architecture Decisions

### D1: Auto-setup Placement

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Before gfx.init | No window to show consent prompt | ❌ Rejected |
| After gfx.init, before ExtState load | Window exists, user can see prompt | ✅ **Chosen** |
| After ExtState load, before auto-start | Equivalent timing | ❌ Same effect, noisier diff |

**Rationale**: `gfx.init` is blocking and establishes the visible window. Consent prompt needs the window. Insert auto-setup at line 216 (after `gfx.setfont`, before ExtState load). If user declines, skip. If already consented (ExtState), skip silently.

### D2: Track Selection Strategy

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Always create new track | Clutters project | ❌ Rejected |
| Scan + create if none suitable | Minimal disruption | ✅ **Chosen** |
| Find track by name "GROVE MIDI" | Brittle, user may rename | ❌ Rejected |

**Rationale**: Scan all tracks. A track is "suitable" if armed + monitoring on + input set to virtual MIDI keyboard. If found, do nothing. If none found, prompt → create → configure. This is robust against renames and existing setups.

### D3: I_RECINPUT Value for Virtual MIDI Keyboard

| Option | Value | Tradeoff |
|--------|-------|----------|
| All channels | `4096` (0x1000) | ✅ Works for any channel |
| Specific channel | `4097`-`4111` (0x1001-0x100F) | ❌ Over-engineered; channel is in midi_channel |

**Choice**: `4096` — virtual MIDI keyboard, all channels. Confirmed by REAPER API: bit 12 set = virtual MIDI keyboard source, low 5 bits = 0 (all channels).

### D4: `force` Param for SendMidi Note-Off Gate

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `SendMidi(note, on, velocity?, force?)` | Signature change, 4th param | ✅ **Chosen** |
| `ForceNoteOff(note)` as separate function | More code, callers must know 2 APIs | ❌ Rejected |

**Rationale**: 4th optional boolean `force`. When `force=true`, skip the `cur <= 0` gate and always send 0x80. When `force=false` (default), existing ref-count logic applies. Callers: `AllNotesOff()` and `sequencer.Stop()` pass `force=true`.

Implementation diff on line 27:
```lua
-- Old: always sends 0x80 on note-off
reaper.StuffMIDIMessage(ch, on and 0x90 or 0x80, note, on and vel or 0)
-- New: only send 0x80 when force=true or ref-count reaches 0
```
Move the actual `reaper.StuffMIDIMessage` for 0x80 inside the `cur <= 0` block, unless `force=true` bypasses it.

### D5: Catch-Up State-Only (Sequencer)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Skip catch-up entirely | Missed visual state updates | ❌ Rejected |
| Update state only, no MIDI | No clicks, correct visual | ✅ **Chosen** |

**Rationale**: Replace lines 101-110 in `sequencer.lua`: instead of `midi.TriggerChord(...)` + `midi.SendMidi(n, false)`, do nothing for MIDI — only advance `LastMeasure` and `CurrentStep`. The skipped slot's chord never actually played, so there's nothing to stop. The next non-skipped measure will trigger normally.

### D6: VIEW_MODES.ISLAND — Remove Dead Code

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Add `ISLAND = 3` | Keeps dead code alive, island is NOT a view mode | ❌ Rejected |
| Remove branch entirely | Simplifies code, matches reality | ✅ **Chosen** |

**Rationale**: Island is toggled via `midi.ToggleIsland()` as a content expansion within FULL mode, not a separate view mode (`config.VIEW_MODES` only has `FULL=1, COMPACT=2`). The ISLAND branch in `compact-init.lua:60` is dead code: `config.VIEW_MODES.ISLAND` is nil, so the condition never matches. Remove the entire `if ... ISLAND then ... end` block.

## Data Flow

```
Init()
  ├─ Auto-setup: scan tracks → consent? → create/configure
  ├─ gfx.init() ... MainLoop
      └─ CheckFocus()
           ├─ focus gain → InterceptMappedKeys(true)
           └─ focus loss → AllNotesOff() + [NEW] sequencer.Stop()
```

```
midi.SendMidi(note, on, velocity, force?)
  ├─ note-on (0x90): inc ref-count, always send
  └─ note-off (0x80): [NEW] only send if force=true OR cur <= 0
```

```
sequencer.Run() — catch-up loop
  [OLD] TriggerChord + SendMidi(n, false) → audible clicks
  [NEW] state-only: advance LastMeasure, no MIDI calls
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/main.lua` | Modify | Add auto-setup call after gfx.setfont, remove redundant line 224 InterceptMappedKeys(false) |
| `src/core/midi.lua` | Modify | Move 0x80 behind ref-count gate + `force` param + nil guard for ExportToMidi item take |
| `src/core/sequencer.lua` | Modify | Replace TriggerChord+SendMidi with state-only in catch-up loop |
| `src/core/keyboard.lua` | Modify | Add `sequencer.Stop()` alongside `AllNotesOff()` in CheckFocus |
| `src/config.lua` | Modify | N/A — no change needed (ISLAND is not a constant, removing dead code only) |
| `src/ui/compact-init.lua` | Modify | Remove dead ISLAND branch in SwitchViewMode |
| `.llm/knowledge/architecture.md` | Update | Remove VIEW_MODES.ISLAND references, document ref-count gate + force param |

## Interfaces / Contracts

```lua
-- midi.lua
function midi.SendMidi(note, on, velocity?, force?)
    -- force=true bypasses ref-count gate; used by AllNotesOff, sequencer.Stop
    -- force=false/nil (default): only send 0x80 when ref-count reaches 0
end
```

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | Ref-count gate on note-off | SendMidi with multiple note-ons, verify 0x80 only after all released |
| Unit | `force` param bypass | SendMidi(note, false, nil, true) sends 0x80 regardless of count |
| Unit | Catch-up state-only | sequencer.Run() after frame skip — no TriggerChord called in catch-up |
| Unit | nil guard ExportToMidi | Pass nil item/take scenario, verify no crash |
| E2E | Auto-setup consent flow | Mock ExtState, verify track creation/configuration |
| E2E | CheckFocus Stop | Focus loss triggers both AllNotesOff and sequencer.Stop |

## Migration / Rollout

No migration required. Auto-setup activates fresh on next launch. Bug fixes are runtime behavioral changes — existing tests need delta specs if they assert old behavior.

## Open Questions

- [ ] **I_RECINPUT = 4096**: Verify exact REAPER constant for virtual MIDI keyboard. If wrong, tracks won't receive input.
- [ ] **AllNotesOff + sequencer.Stop ordering**: CheckFocus currently calls `midi.AllNotesOff()` then releases intercept. Adding `sequencer.Stop()` — should it be before or after AllNotesOff? (Recommendation: `sequencer.Stop()` first, then `AllNotesOff()` — Stop sends note-offs for sequencer-held notes, AllNotesOff sends for all others + CC 123.)
