extends SceneTree

const GameplayState = preload("res://src/gameplay_state.gd")
const VehicleController = preload("res://src/vehicle_controller.gd")
const TEST_SAVE := "user://package_peddler_one_delivery_e2e.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	_cleanup()
	var state := GameplayState.new()
	_expect(state.select_driver(2) and state.select_vehicle(1), "Driver or vehicle selection failed")
	_expect(state.accept_route().accepted, "Route acceptance failed")
	_expect(state.scan_package(GameplayState.PACKAGE_TRACKING).accepted, "Package scan failed")
	_expect(state.load_package().accepted, "Package load failed")

	var vehicle := VehicleController.new() as PackagePeddlerVehicle
	vehicle.configure(state.selected_vehicle, Color("bd5c35"), 0.9)
	root.add_child(vehicle)
	await process_frame
	vehicle.set_door_open(true)
	vehicle._physics_process(0.25)
	_expect(vehicle.door_open, "Driver door did not open before entry")
	vehicle.set_driving_active(true)
	vehicle.set_door_open(false)
	_expect(state.depart_route().accepted, "Entering loaded vehicle did not depart route")
	_expect(vehicle.toggle_park() and not vehicle.parked, "Vehicle could not shift into Drive")
	Input.action_press("move_forward")
	for frame in range(12):
		vehicle._physics_process(0.1)
	Input.action_release("move_forward")
	_expect(vehicle.speed > 1.0, "Vehicle did not drive")
	Input.action_press("vehicle_brake")
	for frame in range(15):
		vehicle._physics_process(0.1)
	Input.action_release("vehicle_brake")
	_expect(vehicle.toggle_park() and vehicle.parked, "Vehicle did not stop and park")
	vehicle.set_driving_active(false)
	vehicle.set_door_open(true)
	_expect(state.arrive_at_stop().accepted, "Route did not register arrival")
	_expect(state.retrieve_package().accepted, "Correct loaded package was not retrieved")
	_expect(state.place_package().accepted, "Delivery-zone placement failed")
	var result := state.confirm_delivery()
	_expect(result.accepted and result.reward == 85, "Delivery confirmation failed")
	state.vehicle_position = Vector3(12.0, 0.0, 4.0)
	state.vehicle_rotation_y = 0.75
	_expect(state.save_game(TEST_SAVE), "Completed delivery did not save")
	var loaded := GameplayState.new()
	_expect(loaded.load_game(TEST_SAVE), "Completed delivery did not reload")
	_expect(loaded.selected_driver == "Jordan Reed" and loaded.selected_vehicle == "Cargo Comet", "Driver or vehicle did not persist")
	_expect(loaded.route_phase == "ROUTE_COMPLETE" and loaded.credits == 85, "Completed route or payout did not persist")
	_expect(loaded.vehicle_position.is_equal_approx(Vector3(12.0, 0.0, 4.0)) and is_equal_approx(loaded.vehicle_rotation_y, 0.75), "Vehicle transform did not persist")
	var duplicate := loaded.confirm_delivery()
	_expect(not duplicate.accepted and duplicate.reward == 0 and loaded.credits == 85, "Reload allowed duplicate payout")
	_cleanup()
	if failures.is_empty():
		print("ONE_DELIVERY_E2E_CONTRACT_PASS driver=true vehicle=true door=true drive=true park=true route=true scan_load=true retrieve_place_confirm=true reload=true payout_once=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

