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
- one guarded five-stop warehouse route with five-package scanning/loading, optimized or manually edited order, textual GPS, stop-specific placement/proof, returns, earnings, and once-only payouts;
- a compact fictionalized 3D route with a residential porch, apartment stair approach/unit, restaurant public lobby/counter, oversized safe-placement stop, unsafe-animal yard, warehouse, roads, vehicles, and street details.

The rigged human and neighborhood are functional vertical-slice art, not final likeness-quality or release-quality art. Vehicle access proves door, enter/exit, throttle, braking, steering, and parking state. Five physically separate destinations and the route/economy loop are now wired, but the GPS is a text HUD, the signature/photo proof actions are prompts rather than rich interfaces, the dolly is a static interaction cue, and the dog is a static safety cue. Vehicle suspension, wheel animation, damage, traffic, full-body entry/exit and package-handling animation remain under development.

## Run

Open `project.godot` in Godot 4.7.2 and run the project.

## Controls

- WASD / left stick: move
- Shift / left-stick press: sprint
- Mouse / right stick: camera
- V / controller Y: camera view
- E / controller A: interact
- Escape / controller Menu: pause or resume
- While driving: W/S throttle, brake, and reverse; A/D steer; Space/controller B service brake; P/controller X Park/Drive; E/controller A exit when parked

The driver selector offers **Owner Courier**, **Maya Brooks**, **Jordan Reed**, and **Alex Rivera**. The owner-reference choice uses only the project-owned fictionalized runtime courier; private reference media is not shipped. At the depot selector, press `1`/controller X for the **Parcel Finch**, `2`/controller Y for the **Cargo Comet**, or `Q` to cancel. At the selected driver door, interact once to open it and again to enter. Stop, engage Park, and interact to exit; interact once more outside to close the door. At the flagged home, interact and choose `1` de-escalate, `2` leave, `3` fight, or `4` toggle combat accessibility. Non-combat resolutions remain available.

Five-stop sequence: choose driver and vehicle; use the warehouse planner to accept the optimized order or rotate it manually; interact six times at the package station to scan five packages and load them; enter the vehicle and drive to the active GPS curb marker; Park and exit; register arrival; retrieve the correct package from the vehicle; follow the active delivery marker; place using that stop's safe rule; then use the proof marker. Repeat for all five stops. The apartment uses a walkable exterior ramp/stair approach, the restaurant opens into its public counter area, the oversized stop points to a safe zone beside the outward-opening door, and the animal stop offers wait/contact/undeliverable choices. An undeliverable package must return through the warehouse station. Stop rewards, route bonus, expenses, net earnings, and visible carried/placed state survive save/reload.

See `docs/ENGINE-DECISION.md`, `docs/VERTICAL-SLICE.md`, and `docs/ACCEPTANCE-LEDGER.md`.

## Automated controller check

Run:

```powershell
..\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/controller_contract.gd
```

The test verifies required input actions, the character collider, the camera collision arm, the rigged courier, all three locomotion clips, animation state selection, and movement acceleration.

The separate `tests/vehicle_contract.gd` verifies door animation, driving-camera ownership, throttle, steering, braking, Park, and exit state.

`tests/route_package_contract.gd` verifies route ordering, five archetypes, explicit placement/proof, animal return paths, and once-only payout. `tests/one_delivery_e2e_contract.gd` verifies all five deliveries, mid-route reload, earnings, and duplicate-payout protection. `tests/five_stop_scene_contract.gd` verifies the 15 identity-bound scene markers, world bounds, apartment ramp, restaurant access, and visible carried/placed reload state.
