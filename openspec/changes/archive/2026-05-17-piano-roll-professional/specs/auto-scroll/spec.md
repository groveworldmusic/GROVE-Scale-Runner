# Auto-Scroll Specification

## Purpose

Playhead-follow viewport scrolling during playback. Keeps the playhead visible in the piano roll without manual scrolling, matching DAW convention (FL Studio, Ableton).

## Requirements

### Requirement: Playhead-Follow Activation

Auto-scroll MUST activate automatically when `sequencer_store.GetIsPlaying()` returns `true`. It MUST deactivate when playback stops. When not playing, auto-scroll SHALL be inactive and the viewport SHALL remain at the user's last scroll position.

#### Scenario: Activates on playback start

- GIVEN piano roll at scroll beat 0, sequencer stopped
- WHEN `GetIsPlaying()` becomes `true`
- THEN auto-scroll activates
- AND the viewport SHALL track the playhead position

#### Scenario: Deactivates on stop

- GIVEN auto-scroll active during playback
- WHEN `GetIsPlaying()` becomes `false`
- THEN auto-scroll deactivates
- AND the viewport SHALL remain at its last position

### Requirement: Middle-Third Clamping

The playhead MUST be kept within the middle 1/3 of visible beats during active auto-scroll. When the playhead exits that zone, scroll position SHALL adjust to re-center it. The adjustment SHALL smooth-scroll via linear interpolation over ~100ms (3-4 frames at ~30fps). If the playhead jumps discontinuously (e.g., user clicks a ruler beat marker), the clamp SHALL re-evaluate immediately without smoothing.

#### Scenario: Gradual playhead exit triggers smooth scroll

- GIVEN auto-scroll active, 48 beats visible (range 16-64), playhead at beat 32
- WHEN playhead advances to beat 37 (exits middle third: beats 24-40)
- THEN scroll position SHALL adjust rightward so the playhead re-enters the middle third
- AND the adjustment SHALL be smooth (interpolated across ~3 frames)

#### Scenario: Discontinuous jump avoids smoothing

- GIVEN auto-scroll active, playhead at beat 32
- WHEN user clicks beat 72 in the timeline ruler
- THEN scroll position SHALL jump immediately to center beat 72
- AND no smooth-scroll interpolation SHALL occur

### Requirement: User Scroll Grace Period

When the user manually scrolls during playback (mouse wheel, scrollbar drag, arrow nudge), auto-scroll SHALL enter a 2-second grace period. During this window, auto-scroll SHALL NOT adjust the viewport. If the playhead exits the visible range entirely, auto-scroll SHALL re-engage immediately and reset the grace timer. After 2 seconds of no user scroll input, auto-scroll SHALL resume normal behavior.

#### Scenario: Grace period suppresses auto-scroll

- GIVEN auto-scroll active, playhead in middle-third
- WHEN user manually scrolls right by 8 beats
- THEN auto-scroll SHALL NOT recenter for 2 seconds
- AND the playhead MAY leave the middle-third during that window

#### Scenario: Visible-range escape overrides grace

- GIVEN auto-scroll grace period active
- WHEN the playhead moves completely outside the visible beat range
- THEN auto-scroll SHALL re-engage immediately
- AND the viewport SHALL scroll to bring the playhead back into view

### Requirement: Toggle Button

A toggle button SHALL appear in the timeline ruler area. The button SHALL indicate the current auto-scroll state. Clicking toggles the state. When toggled off, auto-scroll MUST remain off even during playback. The toggle state SHALL persist for the session.

#### Scenario: Toggle off during playback

- GIVEN auto-scroll active during playback
- WHEN user clicks the toggle button
- THEN auto-scroll deactivates
- AND the playhead MAY leave the viewport without automatic adjustment

#### Scenario: Toggle shows visual state

- GIVEN auto-scroll ON
- WHEN the toggle button renders
- THEN it SHALL show an "on" visual state (highlighted/filled)
- WHEN auto-scroll is OFF
- THEN it SHALL show an "off" visual state (dimmed/outlined)

## Acceptance Criteria

- [ ] Auto-scroll activates on playback start, deactivates on stop
- [ ] Playhead stays within middle 1/3 of visible beats during auto-scroll
- [ ] Smooth-scroll on gradual movement; immediate jump on discontinuous playhead change
- [ ] 2-second grace period on user scroll with visible-range escape override
- [ ] Toggle button in timeline ruler, visual on/off state, toggle persists for session
