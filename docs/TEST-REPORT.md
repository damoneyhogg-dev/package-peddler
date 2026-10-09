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
- Headless main-scene startup: exit 0 and `PACKAGE_PEDDLER_READY controller_milestone=1`.
- Controller contract: `CONTROLLER_CONTRACT_PASS actions=12 planar_speed=3.600`.
- Required keyboard/gamepad actions exist.
- Player collider, SpringArm3D camera collision, and active Camera3D exist.
- Simulated forward input accelerates without exceeding configured walk speed.
- Partial analog input preserves stick magnitude (`partial=1.575`).
- Full forward input remains below the 4.2 walk cap (`planar=3.600`).
- Full diagonal input is capped at the configured walk speed (`diagonal=4.200`).
- Appearance profile round-trip passes with six skin tones and three vest styles.

## Not yet verified

- Visual desktop playthrough and physical controller test.
- Final realistic human model and animation blend tree.
- Visual customization screen and rendered vest variants (data foundation only).
- Foot/hand IK, lifting, carrying, stairs, doors, and vehicle transitions.
- Driving, warehouse, route selection, package workflow, five deliveries, earnings, and persistence.

The current scene is an internal controller foundation, not the requested complete vertical slice.
