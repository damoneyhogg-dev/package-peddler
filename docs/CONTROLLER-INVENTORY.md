# Third-person controller inventory

## Engine and authority

- Engine: Godot 4.7.2, Compatibility renderer.
- Authoritative movement/camera script: `src/player_controller.gd`.
- Scene composition: `src/main.gd` creates the graybox world and one player.
- No duplicate movement or camera scripts exist.

## Movement and camera loops

- `_physics_process` reads hardware-independent actions, derives horizontal camera-relative velocity, applies acceleration/braking/gravity, rotates the visual rig, calls `move_and_slide`, and updates provisional gait.
- `_unhandled_input` processes mouse look and capture/release.
- Right-stick look is frame-rate independent.
- SpringArm3D provides camera obstruction contraction; smooth recovery remains to be tuned visually.

## Input actions

- Move, Look, Interact, Sprint, Pause, and Camera are mapped for keyboard/mouse and standard gamepads.
- `Input.get_vector` supplies a radial dead zone.
- Analog movement magnitude is preserved and diagonals are capped.
- Focus loss releases mouse capture and clears horizontal velocity; the controller stores no persistent held-button state.
- Remapping and sensitivity UI remain pending.

## Rig and animation

- `ProvisionalHumanRig` is code-generated test geometry only.
- Procedural limb swing is provisional and not motion capture.
- No external animation clips have been imported yet.
- Planned licensed pipeline: private owner-video reference + MakeHuman CC0 output + Mixamo royalty-free game animations + Blender retarget/optimization.

## Collision and ground

- Player: CharacterBody3D with one named capsule collider.
- Ground and graybox structures: StaticBody3D box colliders.
- Curbs, stairs, slopes, doors, aisles, indoor speed, and interaction anchors remain pending.
