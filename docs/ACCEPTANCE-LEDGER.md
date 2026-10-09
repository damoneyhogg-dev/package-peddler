# Acceptance ledger

## Character and camera

- Camera-relative walk/run with acceleration and braking.
- No sliding while idle; no floating; floor contact remains stable.
- Smooth facing transitions; no instant 180-degree snapping.
- Mouse and right-stick orbit; adjustable sensitivity before slice release.
- Camera collision prevents wall clipping.
- First-person and third-person views preserve control orientation.
- Final slice uses a licensed realistic human, blended idle/walk/run/lift/carry/enter/exit animations, and foot/hand IK where needed.

## Character customization

- Player can select among at least six skin tones.
- Shirt, pants, and high-visibility vest colors are independently selectable.
- At least three visibly different vest styles are available.
- Appearance persists through save/reload and is visible in third-person and cinematics.
- Color choices do not alter hitboxes, movement speed, delivery payout, or combat advantage.

## Vehicle

- Proximity and door-side entry gate.
- Natural enter/exit transition without teleport visible to the player.
- Analog steering, throttle, and braking.
- Vehicle cannot be controlled while on foot.
- A fictional gas station supports parking at a pump, exiting, purchasing a selected fuel amount, enforcing tank capacity, and recording the expense exactly once.
- A fictional vehicle-service center supports confirmed oil, tire, inspection, and optional wash services with explicit cost and elapsed time; completed service state persists and cannot be charged twice.
- Fuel, damage, maintenance, and cargo capacity affect route economics.

## Warehouse and packages

- Route cannot start until accepted packages are scanned and loaded.
- Each fictional package has one tracking ID, stop, dimensions, weight, and status.
- Capacity and package placement are enforced.
- Duplicate scans and wrong-package scans are rejected.

## Route planning

- The route screen shows every accepted stop, its sequence, and estimated route distance/time before departure.
- The player can accept an optimized order or manually reorder stops; either choice updates GPS guidance without changing package ownership or creating duplicate delivery credit.
- The planner calls out obvious backtracking, such as driving past a nearby pending stop and returning later, while still allowing the player's chosen order.
- Recalculation is deterministic for the same route state and never silently drops a stop.

## Deliveries

- Five distinct locations are reachable by driving and walking.
- At least one apartment stop requires legal parking, correct building and unit identification, exterior stair traversal while carrying the assigned package, and confirmation at the correct door.
- At least one commercial restaurant stop requires legal parking, entry through the public lobby, a staff-counter handoff, and signature or equivalent confirmation; staff-only areas remain inaccessible.
- Correct package, address, placement, scan, and confirmation are required.
- At least one oversized-package stop requires an appropriate heavy-carry or dolly interaction and rejects placement that blocks an outward-opening door, walkway, or resident access.
- An unsafe-animal complication supports staying in or returning to the vehicle, contacting the fictional customer, waiting for the animal to be secured, or marking the stop undeliverable; the player cannot confront or harm the animal.
- Stops cannot pay twice.
- Undeliverable status creates a return obligation.

## Economy and persistence

- Gross payout minus fuel, mileage/maintenance, and penalties equals net earnings.
- Route reward is once-only.
- Save/reload restores player, vehicle, route, packages, stops, expenses, and earnings.
- Missing or corrupt save data fails safely to a new profile.

## Contested-delivery encounters (post-core extension)

- Encounters occur only at explicitly flagged fictional delivery stops and only against another courier NPC.
- Player can de-escalate, leave, or choose a non-lethal hand-to-hand fight.
- Combat supports stamina, light/heavy strikes, block, dodge, hit reaction, knockdown, recovery, and a clear stop condition.
- No weapons, gore, attacks on customers, or attacks on uninvolved pedestrians.
- Fighting has believable time, reputation, injury, route, and earnings consequences; it is never a free reward.
- The same encounter cannot grant repeated delivery credit or repeated payout.
- Combat can be disabled in accessibility/gameplay settings, with a non-combat resolution path preserved.
