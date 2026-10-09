# Engine decision

## Selected: Godot 4.7.2, Compatibility renderer

### Why Godot 4

- Free and open source; no purchase or royalty decision is required for this prototype.
- Small portable editor and straightforward Git-friendly text resources.
- CharacterBody3D, SpringArm3D, input mapping, animation trees, navigation, physics, and desktop/web export support the requested slice.
- Compatibility rendering is appropriate for the development laptop's Intel UHD 620 integrated GPU.

### Why Unreal Engine 5 was not selected for this machine

- UE5 is not installed and its editor/build pipeline is substantially heavier.
- The available Intel UHD 620 integrated GPU is below a sensible target for dependable UE5 realistic-environment iteration.
- Selecting UE5 here would increase installation size, shader compilation time, and testing risk before proving the delivery loop.

This decision can be revisited for a future production machine, but the first vertical slice will be built and proved in Godot.

## Existing-solution preflight

The project will use maintained built-in Godot systems before custom replacements: CharacterBody3D for locomotion, SpringArm3D for camera collision, InputMap for keyboard/gamepad actions, AnimationTree for later animation blending, NavigationServer3D for route-area navigation, and a data-driven route model. Third-party assets or add-ons require a clear commercial license recorded in `docs/ASSET-LICENSES.md`.

