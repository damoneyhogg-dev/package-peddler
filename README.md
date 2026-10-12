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
- a four-driver selector (one fictionalized owner-reference profile and three original fictional couriers);
- two selectable vehicles with animated driver doors, enter/exit state, chase cameras, and basic driving;
- a fictionalized 3D neighborhood with a house, road, sidewalks, warehouse, minivan, and street details.

The rigged human and neighborhood are functional vertical-slice art, not final likeness-quality or release-quality art. Vehicle access now proves door, enter/exit, throttle, braking, steering, and parking state. Vehicle suspension, wheel animation, damage, traffic, package handling, the warehouse loop, five deliveries, and the full economy are still under development.

## Run

Open `project.godot` in Godot 4.7.2 and run the project.

## Controls

- WASD / left stick: move
- Shift / left-stick press: sprint
- Mouse / right stick: camera
- V / controller Y: camera view
- E / controller A: interact
- Escape: release mouse
- While driving: W/S throttle, brake, and reverse; A/D steer; Space/controller B service brake; P/controller X Park/Drive; E/controller A exit when parked

The driver selector offers **Owner Courier**, **Maya Brooks**, **Jordan Reed**, and **Alex Rivera**. The owner-reference choice uses only the project-owned fictionalized runtime courier; private reference media is not shipped. At the depot selector, press `1`/controller X for the **Parcel Finch**, `2`/controller Y for the **Cargo Comet**, or `Q` to cancel. At the selected driver door, interact once to open it and again to enter. Stop, engage Park, and interact to exit; interact once more outside to close the door. At the flagged home, interact and choose `1` de-escalate, `2` leave, `3` fight, or `4` toggle combat accessibility. Non-combat resolutions remain available.

See `docs/ENGINE-DECISION.md`, `docs/VERTICAL-SLICE.md`, and `docs/ACCEPTANCE-LEDGER.md`.

## Automated controller check

Run:

```powershell
..\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/controller_contract.gd
```

The test verifies required input actions, the character collider, the camera collision arm, the rigged courier, all three locomotion clips, animation state selection, and movement acceleration.

The separate `tests/vehicle_contract.gd` verifies door animation, driving-camera ownership, throttle, steering, braking, Park, and exit state.
