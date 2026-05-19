# GROVE Scale Runner

**QWERTY-to-MIDI controller for REAPER** — Maps keyboard keys to scale degrees and chord modes for intuitive music performance and composition.

## Features

- **Sequencer** — Step-by-step playback with Reaper sync or internal clock
- **Piano Keyboard UI** — Interactive keyboard with scale degree highlighting
- **Performance Pads** — Drag notes to progression slots
- **Progression Slots** — Page navigation, reordering, and playback
- **Dockable Transport Bar** — Compact HUD mode for minimal screen space
- **MIDI Island** — Advanced MIDI editing overlay
- **Preset Browser** — Save and load performance configurations
- **Velocity Editor** — Per-note velocity control
- **Piano Roll** — Full piano roll editor with snap grid
- **Snap Grid** — Beat quantization for precise timing
- **Velocity Humanization** — Random velocity variation for natural feel

## Installation

### Via ReaPack (recommended)

1. Copy the repository URL: `https://github.com/GroveWorldMusic/GROVE-Scale-Runner`
2. In REAPER, go to **Extensions → ReaPack → Import Repositories**
3. Paste the URL and click **Import**
4. Go to **Extensions → ReaPack → Browse Packages**
5. Find **Scale Runner** and click **Install**
6. The script will appear in your **Actions List** as `Scale Runner`

### Manual Installation

1. Download the latest release from [GitHub](https://github.com/GroveWorldMusic/GROVE-Scale-Runner)
2. Copy `src/` folder to your REAPER Scripts directory (`%APPDATA%/REAPER/Scripts/`)
3. In REAPER, open the **Actions List**, click **New Action → Load ReaScript**
4. Select `src/main.lua`
5. Assign a keyboard shortcut or toolbar button

## Requirements

- REAPER v6.0+
- [js_ReaScriptAPI](https://github.com/ReaTeam/ReaScripts) extension (installable via ReaPack)

## Usage

1. Run the script from the Actions List
2. Use your QWERTY keyboard to play notes mapped to the selected scale
3. Adjust root note, scale, octave, and chord mode from the UI
4. Use the sequencer for step-by-step playback
5. Drag pads to progression slots for complex arrangements

## Configuration

Settings are persisted across sessions via REAPER's ExtState:
- Root note, scale, octave, chord mode
- Inversion and direction
- Grid subdivision
- View offset (window position)
- Scroll behavior

## Support

If you find this tool useful, consider supporting development:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/groveworldmusic)

## License

Licensed under the [MIT License](LICENSE).

© 2026 Andrik Sanz Cordoví
