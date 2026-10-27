# Third-person controller inventory

## Engine and authority

- Engine: Godot 4.7.2, Compatibility renderer.
- Authoritative movement/camera script: `src/player_controller.gd`.
- Scene/workflow coordinator: `src/main.gd`.
- Vehicle authority: `src/vehicle_controller.gd`.
- No duplicate player movement or camera scripts exist.

## Movement and camera loops

- `_physics_process` reads hardware-independent actions, derives horizontal camera-relative velocity, applies acceleration/braking/gravity, rotates the imported courier, calls `move_and_slide`, updates interaction targeting, and selects locomotion clips from measured speed.
- `_unhandled_input` processes mouse look and capture/release.
- Right-stick look is frame-rate independent.
- SpringArm3D provides third-person camera obstruction contraction.
- Vehicle driving switches to a dedicated chase camera; final orbit/collision tuning remains pending.

## Input actions

- Move, Look, Interact, Sprint, Pause, Camera, menu choices, vehicle brake/Park, and optional encounter actions are mapped for keyboard/mouse and standard gamepads.
- `Input.get_vector` supplies a radial dead zone; analog movement magnitude is preserved and diagonals are capped.
- Focus loss releases mouse capture and clears horizontal velocity.
- Current mappings do not yet match the requested final layout: Interact/enter uses A/Cross, driving uses movement axes plus face-button brake, and there is no Jump action.
- Trigger throttle/brake, jump, PlayStation physical validation, remapping, sensitivity, and camera-inversion UI remain pending.

## Rig and animation

- Runtime asset: `assets/characters/courier.glb`.
- Source: MPFB/MakeHuman CC0 human output with the bundled game-engine rig; detailed provenance and hashes are in `docs/ASSET-LICENSES.md` and `docs/CHARACTER-PIPELINE.md`.
- Runtime inventory: 26,756 triangles, 53 bones, four flat materials, and locally authored `Idle`, `Walk`, and `Run` clips.
- Current controller uses `AnimationPlayer` crossfades selected from velocity. It does not yet use an AnimationTree blend graph.
- The runtime GLB is limited to four bone influences per vertex; the editable Blender source can contain additional weights before export.
- Hair, separate clothing/vest meshes, visible appearance variants, backward/strafe/turn/start/stop, jump, scan, lift, carry, set-down, door, seated-driving, entry/exit clips, and foot/hand IK remain pending.
- Mixamo is not part of the open-source baseline. It may be used only as an explicitly approved proprietary/account-gated exception.

## Collision and ground

- Player: CharacterBody3D with one named capsule collider.
- World and provisional buildings: StaticBody3D collision.
- Four perimeter colliders and below-map recovery prevent leaving the compact slice.
- The five-stop scene contract verifies parking clearance, the apartment's walkable ramp beneath its visual stair treatment, and restaurant public-lobby access.
- Final curbs, true stair stepping, slopes, warehouse aisles, door alignment, and facing/line-of-sight interaction filtering remain pending.
