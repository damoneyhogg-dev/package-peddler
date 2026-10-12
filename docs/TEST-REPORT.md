# Test report

Date: 2026-10-12

## Environment

- Godot: 4.7.2 stable, portable workspace installation
- Renderer: GL Compatibility
- CPU: Intel Core i7-8650U
- RAM: 15.8 GB
- GPU: Intel UHD Graphics 620

## Passed

- Godot editor import/parser: exit 0.
- Headless main-scene startup: exit 0 and `PACKAGE_PEDDLER_READY character=rigged environment=vertical_slice vehicle_swap=true contested_address=true`.
- Character asset contract: `CHARACTER_ASSET_CONTRACT_PASS rigged=true clips=3`.
- Controller contract: `CONTROLLER_CONTRACT_PASS actions=13 modal_freeze=true camera_leak_blocked=true partial=1.575 planar=3.600 diagonal=4.200 stopped=0.000 sprint=7.000 recovery=true rigged=true`.
- Gameplay state contract: `GAMEPLAY_STATE_CONTRACT_PASS vehicles=2 phases=true peaceful=2 combat_actions=4 win_loss_retreat=true persistence=true validation=true idempotent_reward=true`.
- Main contract: `MAIN_CONTRACT_PASS pause=true contextual_anchors=5 drivers=4 vehicle_cancel=true camera_leak_blocked=true encounter_choices=true world_boundaries=4 environment_features=10`.
- Vehicle contract: `VEHICLE_CONTRACT_PASS door_open_close=true enter_exit=true throttle=true steering=true brake=true park=true`.
- Route/package contract: `ROUTE_PACKAGE_CONTRACT_PASS guards=true scan_once=true load=true retrieve=true placement=true confirmation_atomic=true payout_once=true`.
- One-delivery end-to-end contract: `ONE_DELIVERY_E2E_CONTRACT_PASS driver=true vehicle=true door=true drive=true park=true route=true scan_load=true retrieve_place_confirm=true reload=true payout_once=true`.
- Blender export: 26,756 triangles, 53 bones, four materials, and embedded Idle/Walk/Run actions.
- Off-screen GPU render passed at 1280x720 using Intel UHD Graphics 620 / OpenGL 3.3 Compatibility; idle, walk, and run poses were visually inspected.
- Thirteen required movement/camera/interaction/retreat input actions exist; physical-device playtesting of the new mappings remains outstanding.
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
- Depot vehicle selector contracts cover two named options, modal opening/cancellation, movement lock, visible text, persistence API, and suppression of the shared Y camera action until release.
- Four-driver selection covers the fictionalized owner-reference courier plus three original fictional profiles, saved selection, and visible runtime color badges.
- Both fictional vehicles now have a collision body, animated driver door, dedicated chase camera, exclusive driving state, throttle/reverse, speed-dependent steering, service braking, Park gating, and stopped/parked exit protection.
- State/API contracts cover de-escalate, leave, win, loss, retreat, block, dodge, stamina exhaustion, inactive/disabled combat rejection, consequence values, accessibility reload, malformed/wrong-schema fallback, semantic repair/clamping, temporary-save cleanup, and reward idempotency. These are automated state/UI contracts, not a claim of animation-rich physical combat.
- Controller regression measures zero retained velocity and zero position drift while modal controls are disabled.
- Owner desktop playtest passed keyboard walking, backward movement, sprint, camera movement/view switching, pause/resume, and the corrected platform-edge protection on the target laptop.

## Not yet verified

- Physical gamepad test; existing gamepad checks are simulated contracts only.
- Owner interactive playthrough of the new vehicle-and-one-delivery loop.
- Final likeness-quality character, hair, refined clothing geometry, and AnimationTree blend graph.
- Visual customization screen and rendered vest variants (data foundation only).
- Foot/hand IK, lifting animations, stairs, and natural full-body vehicle transitions.
- Refined vehicle suspension, wheel animation, damage, traffic, four additional deliveries, and the full economy model.

The current scene is a playable one-delivery vertical slice with four-driver choice, two vehicle choices, animated doors, basic driving/parking, route acceptance, scan/load/retrieve/place/confirm, and save-safe once-only payout. Package motion is still represented by a carried box prop rather than hand IK, and the project is not yet the complete five-delivery game.
