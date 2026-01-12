# Duwertje (Godot Starter)

This is a scaffold to port the HTML/JS prototype into Godot 4.x.

## Setup
1) Install Godot 4.x (standard) on macOS.
2) Open Godot → Import → Select the `godot_starter/` folder.
3) In Project Settings:
   - Display → Window → Width: 1000, Height: 640 (to match the prototype)
   - Input Map: add actions and keys
     - ui_left → Left
     - ui_right → Right
     - ui_up → Up
     - grab → Space
     - reset → R
4) AutoLoad (Singletons):
   - Add `scripts/save_manager.gd` as name `SaveManager` (Enabled).
   - Optionally add `scripts/audio_manager.gd` as name `AudioManager`.
5) Set `scenes/Main.tscn` as the Main Scene.

## Files
- scenes/Main.tscn: Root scene that spawns Forklift, Piece, Slot, HUD.
- scenes/Forklift.tscn: Forklift node with `scripts/forklift.gd`.
- scenes/Piece.tscn: Movable piece with `scripts/piece.gd`.
- scenes/Slot.tscn: Slot to snap into with `scripts/slot.gd`.
- scenes/HUD.tscn: Canvas-layer HUD with `scripts/hud.gd`.
- scripts/main.gd: Game loop, interactions, snapping, wrapping, reset.
- scripts/hud.gd: shows velocity and hold state.
- scripts/save_manager.gd: JSON persistence in `user://save.json`.
- scripts/audio_manager.gd: Simple hooks for click/release/thrust.

HUD shows velocity, hold state, and save stats (attempts, completed, best time).

## Notes
- This uses vector-style drawing via `_draw()` to emulate your Canvas look.
- Audio uses stubbed methods; replace with AudioStreamPlayers and real samples as desired.
- Save data format is JSON with fields: completed_count, attempts, best_time_seconds, last_played_iso.
- If you change scene/script paths, update `res://` paths inside `.tscn` files accordingly.

### Adding basic audio
1) In `scenes/Main.tscn` (or a dedicated scene), add three `AudioStreamPlayer` nodes: `Click`, `Release`, `Engine`.
2) Load short sound files for click/release. Set `Engine.stream` to a loopable low engine hum and enable `Autoplay`.
3) Update `scripts/audio_manager.gd` to get these nodes (e.g., via autoload or by path) and implement:
   - `click()`: `Click.play()`
   - `release()`: `Release.play()`
   - `thrust(on)`: set `Engine.volume_db` to e.g. `-10` when on, `-80` when off.

## Next Steps
- Run the project and verify movement, grabbing (Space), snapping, and reset (R).
- Confirm the `user://save.json` file updates on completion.
- Replace visuals/audio incrementally as needed.

## TODO
- Add Cheer volume slider in Help modal. Let players control the "triumph" sound volume independently using the `scripts/audio_manager.gd` and add an HBox row labeled "Cheer" with an `HSlider` (range `-40..0 dB`, step `1`). Initialize with `AudioManager. Show current value label (e.g., `-12 dB`).

- Persist volume settings inHelp modal (e.g., via a SaveManager) so they’re retained between sessions. store numeric volume fields in `user://save.json`

- Pause gameplay while Help is open (get_tree().paused = true/false).Closing the modal resumes gameplay seamlessly.

