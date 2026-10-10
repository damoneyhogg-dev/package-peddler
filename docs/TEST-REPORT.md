# Test report

Date: 2026-10-09

## Environment

- Godot: 4.7.2 stable, portable workspace installation
- Renderer: GL Compatibility
- CPU: Intel Core i7-8650U
- RAM: 15.8 GB
- GPU: Intel UHD Graphics 620

## Passed

- Godot editor import/parser: exit 0.
- Headless main-scene startup: exit 0 and `PACKAGE_PEDDLER_READY character=rigged environment=vertical_slice`.
- Character asset contract: `CHARACTER_ASSET_CONTRACT_PASS rigged=true clips=3`.
- Controller contract: `CONTROLLER_CONTRACT_PASS actions=12 partial=1.575 planar=3.600 diagonal=4.200 stopped=0.000 sprint=7.000 recovery=true rigged=true`.
- Gameplay state contract: `GAMEPLAY_STATE_CONTRACT_PASS vehicles=2 combat_toggle=true knockdown=true persistence=true idempotent_reward=true`.
- Main contract: `MAIN_CONTRACT_PASS pause=true contextual_anchors=3 vehicle_cancel=true encounter_choices=true world_boundaries=4 environment_features=10`.
- Blender export: 26,756 triangles, 53 bones, four materials, and embedded Idle/Walk/Run actions.
- Off-screen GPU render passed at 1280x720 using Intel UHD Graphics 620 / OpenGL 3.3 Compatibility; idle, walk, and run poses were visually inspected.
- Required keyboard/gamepad actions exist.
- Player collider, SpringArm3D camera collision, and active Camera3D exist.
- Simulated forward input accelerates without exceeding configured walk speed.
- Partial analog input preserves stick magnitude (`partial=1.575`).
- Full forward input remains below the 4.2 walk cap (`planar=3.600`).
- Full diagonal input is capped at the configured walk speed (`diagonal=4.200`).
- Released input brakes the character to rest (`stopped=0.000`).
- Sprint reaches the configured cap without overshoot (`sprint=7.000`).
- Contextual interaction selects only an in-range interaction anchor and clears it after leaving range.
- Pause input now freezes the scene, shows a pause notice, releases the mouse, and resumes through the same action.
- Four invisible physical world boundaries prevent leaving the playable slice, with a below-map recovery point as a fallback.
- The live player uses the imported MPFB courier rather than the former capsule-based procedural person.
- Idle, Walk, and Run play on the real 53-bone skeleton and transition from controller velocity.
- A fictionalized authored 3D neighborhood now includes a road, sidewalks, house facade, warehouse/loading dock, minivan, trees, utility poles, mailboxes, hydrant, and traffic barriers.
- Appearance profile round-trip passes with six skin tones and three vest styles.
- Depot vehicle selector exposes two named fictional options, cancellation, keyboard/gamepad mappings, visible feedback, and saved selection.
- The flagged contested address exposes de-escalate, leave, and optional non-lethal fight paths. Automated checks cover combat disable, stamina/knockdown completion, consequences, save/reload, and reward idempotency.
- Owner desktop playtest passed keyboard walking, backward movement, sprint, camera movement/view switching, pause/resume, and the corrected platform-edge protection on the target laptop.

## Not yet verified

- Physical gamepad test; existing gamepad checks are simulated contracts only.
- Final likeness-quality character, hair, refined clothing geometry, and AnimationTree blend graph.
- Visual customization screen and rendered vest variants (data foundation only).
- Foot/hand IK, lifting, carrying, stairs, doors, and vehicle transitions.
- Driving, warehouse, route selection, package workflow, five deliveries, and the full economy/persistence model. Only the bounded vehicle/encounter state currently persists.

The current scene is a playable character-and-environment vertical-slice milestone with a bounded vehicle-choice and contested-address foundation. It is still not the complete five-delivery game: package handling, driving, warehouse workflow, delivery stops, and the full economy remain incomplete.
