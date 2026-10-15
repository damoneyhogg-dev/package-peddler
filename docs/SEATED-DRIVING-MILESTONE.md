# Seated Driving Presentation Milestone

## Implemented

- A visible rigged courier remains seated while either playable vehicle is occupied.
- The authored seated pose bends the hips and knees and keeps both arms directed toward steering-wheel targets.
- Steering input rotates the visible wheel and applies a small corresponding arm/torso adjustment.
- Changing between Park and Drive triggers a short right-hand reach toward an original center selector, followed by a return to the wheel.
- Cancelling or exiting resets the reach and seated pose without changing the active camera unexpectedly.
- Driver-seat, wheel, selector, and hand-target geometry is original, unbranded provisional art.

The motion timing and general posture are informed by private reference Clip 31. No private video, extracted frame, person, vehicle interior, road, plate, or brand is imported or shipped.

## Verification

The vehicle contract verifies the seated courier, steering-wheel/selector props, wheel-hand and selector targets, Park/Drive reach, hand return, cancellation, camera continuity, and visibility cleanup on exit. Existing route, payout, save, and delivery semantics are unchanged.

## Provisional limitations

This is an authored procedural pose on the current licensed courier rig, not final motion capture or hand IK. Exact palm contact, finger grip, foot-to-pedal contact, individualized driver bodies/clothing, interior detail, steering-wheel physics, and final vehicle art remain future work. Physical Xbox and PlayStation controller testing is still required.
