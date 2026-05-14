# Auto Track Setup Specification

## Purpose
Automatic track creation/selection with arm, monitoring, MIDI input routing, ExtState persistence, and user consent prompt.

## Requirements

### A1: Track Scan
System MUST scan existing tracks for arm=1 AND monitoring=1 AND MIDI input routing before creating.

#### Scenario: Existing track found
- GIVEN a track with arm=1, monitoring=1, MIDI input=all channels
- WHEN system inits
- THEN no track created — existing track reused

#### Scenario: No suitable track
- GIVEN no track meets criteria
- WHEN system inits
- THEN user consent prompt shown

### A2: Track Creation
With user consent, system MUST create a new track with arm=1, monitoring=1, MIDI input=all channels.

#### Scenario: Creates configured track
- GIVEN user consent granted
- WHEN auto-setup executes
- THEN track created with correct properties

#### Scenario: Consent denied
- GIVEN user refuses consent
- WHEN auto-setup executes
- THEN no track modification

### A3: ExtState Persistence
Completion flag MUST persist via SetExtState and be checked via GetExtState on init.

#### Scenario: First run
- GIVEN no ExtState flag exists
- WHEN system inits
- THEN track scan runs

#### Scenario: Subsequent runs
- GIVEN ExtState flag set from previous run
- WHEN system inits
- THEN scan skipped — no prompt
