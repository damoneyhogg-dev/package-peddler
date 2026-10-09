# Acceptance ledger

## Character and camera

- Camera-relative walk/run with acceleration and braking.
- No sliding while idle; no floating; floor contact remains stable.
- Smooth facing transitions; no instant 180-degree snapping.
- Mouse and right-stick orbit; adjustable sensitivity before slice release.
- Camera collision prevents wall clipping.
- First-person and third-person views preserve control orientation.
- Final slice uses a licensed realistic human, blended idle/walk/run/lift/carry/enter/exit animations, and foot/hand IK where needed.

## Vehicle

- Proximity and door-side entry gate.
- Natural enter/exit transition without teleport visible to the player.
- Analog steering, throttle, and braking.
- Vehicle cannot be controlled while on foot.
- Fuel, damage, maintenance, and cargo capacity affect route economics.

## Warehouse and packages

- Route cannot start until accepted packages are scanned and loaded.
- Each fictional package has one tracking ID, stop, dimensions, weight, and status.
- Capacity and package placement are enforced.
- Duplicate scans and wrong-package scans are rejected.

## Deliveries

- Five distinct locations are reachable by driving and walking.
- Correct package, address, placement, scan, and confirmation are required.
- Stops cannot pay twice.
- Undeliverable status creates a return obligation.

## Economy and persistence

- Gross payout minus fuel, mileage/maintenance, and penalties equals net earnings.
- Route reward is once-only.
- Save/reload restores player, vehicle, route, packages, stops, expenses, and earnings.
- Missing or corrupt save data fails safely to a new profile.

