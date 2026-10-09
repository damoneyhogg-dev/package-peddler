# Package Peddler

Realistic third-person courier and business simulator. This repository begins with a deliberately small, testable vertical slice before any open-world expansion.

## Current verified target

Milestone 1 is the character controller foundation:

- camera-relative walking and sprinting;
- smooth turning and acceleration/braking;
- mouse and controller camera orbit;
- third-person camera collision;
- first-person/third-person toggle;
- keyboard and standard gamepad mappings;
- provisional procedural human used only to test motion.

The procedural human and graybox buildings are **not final art** and are not claimed as realistic assets.

## Run

Open `project.godot` in Godot 4.7.2 and run the project.

## Controls

- WASD / left stick: move
- Shift / left-stick press: sprint
- Mouse / right stick: camera
- V / controller Y: camera view
- E / controller A: interact
- Escape: release mouse

See `docs/ENGINE-DECISION.md`, `docs/VERTICAL-SLICE.md`, and `docs/ACCEPTANCE-LEDGER.md`.

