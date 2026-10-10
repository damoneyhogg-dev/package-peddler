# Package Peddler

Realistic third-person courier and business simulator. This repository builds a deliberately small, testable vertical slice before any open-world expansion.

## Current verified target

The current milestone includes:

- camera-relative walking and sprinting;
- smooth turning and acceleration/braking;
- mouse and controller camera orbit;
- third-person camera collision;
- first-person/third-person toggle;
- keyboard and standard gamepad mappings;
- a 26,756-triangle MPFB/MakeHuman courier with a 53-bone game rig;
- locally authored idle, walk, and run animation clips;
- a fictionalized 3D neighborhood with a house, road, sidewalks, warehouse, minivan, and street details.

The rigged human and neighborhood are functional vertical-slice art, not final likeness-quality or release-quality art. Driving, package handling, the warehouse loop, five deliveries, economy, and persistence are still under development.

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

## Automated controller check

Run:

```powershell
..\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/controller_contract.gd
```

The test verifies required input actions, the character collider, the camera collision arm, the rigged courier, all three locomotion clips, animation state selection, and movement acceleration.
