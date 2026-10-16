extends SceneTree

const VehicleController = preload("res://src/vehicle_controller.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "vehicle_brake", "vehicle_park", "vehicle_throttle", "vehicle_brake_reverse", "menu_cancel", "interact"]:
		_expect(InputMap.has_action(action), "Missing vehicle input: %s" % action)
	var vehicle := VehicleController.new() as PackagePeddlerVehicle
	vehicle.configure("Contract Van", Color.BLUE)
	root.add_child(vehicle)
	await process_frame
	_expect(vehicle.get_node_or_null("VehicleCollision") is CollisionShape3D, "Vehicle collision is missing")
	_expect(vehicle.get_node_or_null("DriverDoorPivot/DriverDoor") is MeshInstance3D, "Animated driver door is missing")
	_expect(vehicle.get_node_or_null("VehicleCameraRig/VehicleCameraCollisionArm") is SpringArm3D, "Vehicle camera collision arm is missing")
	_expect(vehicle.get_node_or_null("VehicleCameraRig/VehicleCameraCollisionArm/VehicleCamera") is Camera3D, "Vehicle camera is missing")
	_expect(is_equal_approx(vehicle.vehicle_camera_arm.spring_length, 5.8), "Vehicle chase-camera distance is incorrect")
	_expect(vehicle.get_node_or_null("SteeringWheel") is Node3D and vehicle.get_node_or_null("CenterSelector") is MeshInstance3D, "Cockpit wheel or center selector is missing")
	_expect(vehicle.get_node_or_null("LeftHandWheelTarget") is Marker3D and vehicle.get_node_or_null("RightHandWheelTarget") is Marker3D and vehicle.get_node_or_null("SelectorReachTarget") is Marker3D, "Authored driver hand targets are missing")
	_expect(vehicle.seated_driver is Node3D and vehicle.seated_driver_skeleton is Skeleton3D and not vehicle.seated_driver.visible, "Seated courier presentation did not initialize hidden")
	vehicle.set_door_open(true)
	vehicle._physics_process(0.25)
	_expect(vehicle.door_open and vehicle.door_pivot.rotation.y < -0.1, "Door did not animate open")
	vehicle.set_door_open(false)
	for step in range(10):
		vehicle._physics_process(0.1)
	_expect(not vehicle.door_open and absf(vehicle.door_pivot.rotation.y) < 0.01, "Door did not animate closed")
	vehicle.set_driving_active(true)
	_expect(vehicle.driving_active and vehicle.vehicle_camera.current and vehicle.seated_driver.visible, "Entering did not activate the driving camera and seated courier")
	_expect(vehicle._driver_bone_vehicle_position("hand_l").distance_to((vehicle.get_node("LeftHandWheelTarget") as Marker3D).position) < 0.02, "Left hand is not aligned to its steering-wheel target")
	_expect(vehicle._driver_bone_vehicle_position("hand_r").distance_to((vehicle.get_node("RightHandWheelTarget") as Marker3D).position) < 0.02, "Right hand is not aligned to its steering-wheel target")
	_expect(vehicle.parked and vehicle.toggle_park() and not vehicle.parked, "Vehicle could not shift from Park to Drive")
	vehicle._update_driving_presentation(vehicle.driving_presentation_duration * 0.5)
	vehicle._apply_seated_driver_pose(vehicle.selector_reach_weight, 0.0)
	_expect(vehicle.driving_presentation_kind == "selector_reach" and vehicle.selector_reach_weight > 0.9, "Park/Drive change did not reach toward the center selector")
	_expect(vehicle._driver_bone_vehicle_position("hand_r").distance_to((vehicle.get_node("SelectorReachTarget") as Marker3D).position) < 0.02, "Right hand did not align to the center-selector reach target")
	_expect(vehicle.vehicle_camera.current, "Selector reach interrupted the active vehicle camera")
	vehicle.cancel_driving_presentation()
	_expect(vehicle.driving_presentation_kind == "" and is_zero_approx(vehicle.selector_reach_weight) and vehicle.vehicle_camera.current, "Cancelling the selector reach did not safely restore hands/camera")
	Input.action_press("look_right")
	vehicle._update_vehicle_camera(0.25)
	Input.action_release("look_right")
	var orbit_yaw := vehicle.vehicle_camera_yaw
	_expect(absf(orbit_yaw) > 0.1, "Right-stick camera orbit did not move the chase camera")
	for step in range(40):
		vehicle._update_vehicle_camera(0.1)
	_expect(absf(vehicle.vehicle_camera_yaw) < absf(orbit_yaw) * 0.2, "Vehicle camera did not return stably behind the vehicle")
	Input.action_press("move_forward")
	for step in range(12):
		vehicle._physics_process(0.1)
	Input.action_release("move_forward")
	_expect(vehicle.speed > 1.0 and vehicle.speed <= vehicle.maximum_forward_speed, "Throttle did not accelerate within forward limit")
	var before_turn := vehicle.rotation.y
	Input.action_press("move_left")
	vehicle._physics_process(0.2)
	Input.action_release("move_left")
	_expect(not is_equal_approx(before_turn, vehicle.rotation.y), "Steering did not rotate moving vehicle")
	_expect(absf(vehicle.steering_wheel.rotation.z) > 0.01, "Steering input did not animate the wheel/hand presentation")
	Input.action_press("vehicle_brake")
	for step in range(15):
		vehicle._physics_process(0.1)
	Input.action_release("vehicle_brake")
	_expect(absf(vehicle.speed) < 0.01, "Service brake did not stop vehicle")
	Input.action_press("vehicle_throttle", 0.7)
	for step in range(8):
		vehicle._physics_process(0.1)
	Input.action_release("vehicle_throttle")
	_expect(vehicle.speed > 0.5, "Controller right trigger did not apply throttle")
	Input.action_press("vehicle_brake_reverse")
	for step in range(20):
		vehicle._physics_process(0.1)
	Input.action_release("vehicle_brake_reverse")
	_expect(vehicle.speed < -0.1, "Controller left trigger did not brake and engage reverse")
	Input.action_press("vehicle_brake")
	for step in range(10):
		vehicle._physics_process(0.1)
	Input.action_release("vehicle_brake")
	_expect(vehicle.toggle_park() and vehicle.parked, "Stopped vehicle could not engage Park")
	_expect(vehicle.has_exit_clearance(), "Clear driver-side exit was incorrectly reported blocked")
	var exit_blocker := StaticBody3D.new()
	var exit_collision := CollisionShape3D.new()
	var exit_box := BoxShape3D.new()
	exit_box.size = Vector3(0.7, 1.8, 0.7)
	exit_collision.shape = exit_box
	exit_blocker.add_child(exit_collision)
	root.add_child(exit_blocker)
	exit_blocker.global_position = vehicle.exit_position() + Vector3.UP * 0.9
	await physics_frame
	_expect(not vehicle.has_exit_clearance(), "Blocked driver-side exit passed the clearance guard")
	vehicle.set_driving_active(false)
	_expect(not vehicle.driving_active and not vehicle.vehicle_camera.current and not vehicle.seated_driver.visible, "Exit did not deactivate driving camera and seated courier")
	if failures.is_empty():
		print("VEHICLE_CONTRACT_PASS door_open_close=true exit_clearance=true enter_exit=true keyboard_throttle=true trigger_throttle_reverse=true steering=true brake=true park=true seated_driver=true camera_collision=true camera_orbit_return=true wheel_hands=true selector_reach=true cancel_camera=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("VEHICLE_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
