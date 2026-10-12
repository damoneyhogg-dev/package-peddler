extends SceneTree

const VehicleController = preload("res://src/vehicle_controller.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "vehicle_brake", "vehicle_park", "interact"]:
		_expect(InputMap.has_action(action), "Missing vehicle input: %s" % action)
	var vehicle := VehicleController.new() as PackagePeddlerVehicle
	vehicle.configure("Contract Van", Color.BLUE)
	root.add_child(vehicle)
	await process_frame
	_expect(vehicle.get_node_or_null("VehicleCollision") is CollisionShape3D, "Vehicle collision is missing")
	_expect(vehicle.get_node_or_null("DriverDoorPivot/DriverDoor") is MeshInstance3D, "Animated driver door is missing")
	_expect(vehicle.get_node_or_null("VehicleCameraRig/VehicleCamera") is Camera3D, "Vehicle camera is missing")
	vehicle.set_door_open(true)
	vehicle._physics_process(0.25)
	_expect(vehicle.door_open and vehicle.door_pivot.rotation.y < -0.1, "Door did not animate open")
	vehicle.set_door_open(false)
	for step in range(10):
		vehicle._physics_process(0.1)
	_expect(not vehicle.door_open and absf(vehicle.door_pivot.rotation.y) < 0.01, "Door did not animate closed")
	vehicle.set_driving_active(true)
	_expect(vehicle.driving_active and vehicle.vehicle_camera.current, "Entering did not activate driving camera")
	_expect(vehicle.parked and vehicle.toggle_park() and not vehicle.parked, "Vehicle could not shift from Park to Drive")
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
	Input.action_press("vehicle_brake")
	for step in range(15):
		vehicle._physics_process(0.1)
	Input.action_release("vehicle_brake")
	_expect(absf(vehicle.speed) < 0.01, "Service brake did not stop vehicle")
	_expect(vehicle.toggle_park() and vehicle.parked, "Stopped vehicle could not engage Park")
	vehicle.set_driving_active(false)
	_expect(not vehicle.driving_active and not vehicle.vehicle_camera.current, "Exit did not deactivate driving camera")
	if failures.is_empty():
		print("VEHICLE_CONTRACT_PASS door_open_close=true enter_exit=true throttle=true steering=true brake=true park=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("VEHICLE_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
