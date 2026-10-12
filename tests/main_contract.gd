extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame

	_expect(game.pause_label is Label, "Pause notice was not created")
	_expect(not game.pause_label.visible, "Pause notice starts visible")
	game._toggle_pause()
	_expect(paused, "Pause action did not pause the scene tree")
	_expect(game.pause_label.visible, "Pause action did not show the pause notice")
	game._toggle_pause()
	_expect(not paused, "Second pause action did not resume the scene tree")
	_expect(not game.pause_label.visible, "Resume did not hide the pause notice")

	var vehicle_point := game.get_node_or_null("VehicleDoor")
	var vehicle_selector := game.get_node_or_null("VehicleSelector")
	var driver_kiosk := game.get_node_or_null("DriverKiosk")
	var warehouse_point := game.get_node_or_null("WarehouseEntrance")
	var contested_point := game.get_node_or_null("ContestedAddress")
	var package_station := game.get_node_or_null("PackageStation")
	var delivery_stop := game.get_node_or_null("DeliveryStop")
	_expect(vehicle_point is Marker3D and vehicle_point.is_in_group("interactable"), "Vehicle interaction anchor is missing")
	_expect(vehicle_selector is Marker3D and vehicle_selector.is_in_group("interactable"), "Vehicle selector anchor is missing")
	_expect(driver_kiosk is Marker3D and driver_kiosk.is_in_group("interactable"), "Driver selector anchor is missing")
	_expect(warehouse_point is Marker3D and warehouse_point.is_in_group("interactable"), "Warehouse interaction anchor is missing")
	_expect(contested_point is Marker3D and contested_point.is_in_group("interactable"), "Contested-address anchor is missing")
	_expect(package_station is Marker3D and package_station.is_in_group("interactable"), "Package station anchor is missing")
	_expect(delivery_stop is Marker3D and delivery_stop.is_in_group("interactable"), "Delivery stop anchor is missing")
	_expect(vehicle_point.get_meta("interaction_kind") == "vehicle_access", "Vehicle door anchor is not wired to access")
	_expect(vehicle_selector.get_meta("interaction_kind") == "vehicle_swap", "Vehicle selector is not wired to swap choice")
	_expect(driver_kiosk.get_meta("interaction_kind") == "driver_select", "Driver kiosk is not wired to driver choice")
	game._open_driver_menu()
	_expect(game.active_modal == "driver" and "Owner Courier" in game.modal_label.text and "Alex Rivera" in game.modal_label.text, "Four-driver selector did not open")
	game._choose_driver(3)
	_expect(game.gameplay_state.selected_driver == "Alex Rivera" and game.player.driver_variant == 3, "Fourth driver did not apply to gameplay and runtime character")
	_expect(contested_point.get_meta("interaction_kind") == "contested_address", "Address anchor is not flagged for its encounter")
	_expect(warehouse_point.get_meta("interaction_kind") == "route_terminal", "Warehouse entrance is not wired to route selection")
	_expect(package_station.get_meta("interaction_kind") == "package_station", "Package station is not wired to scan/load")
	_expect(delivery_stop.get_meta("interaction_kind") == "delivery_stop", "Delivery stop is not wired to placement/confirmation")
	var starting_vehicle: String = game.gameplay_state.selected_vehicle
	game._open_vehicle_menu()
	_expect(game.active_modal == "vehicle" and game.modal_panel.visible, "Vehicle choice UI did not open")
	_expect("Parcel Finch" in game.modal_label.text and "Cargo Comet" in game.modal_label.text, "Vehicle choices are not unambiguous in the modal")
	_expect(not game.player.controls_enabled, "Player can move while vehicle choice is open")
	Input.action_press("camera_toggle")
	game._close_modal("Contract cancellation")
	game.player._update_camera_mode()
	_expect(not game.player.first_person, "Vehicle selection Y input leaked into camera toggle")
	Input.action_release("camera_toggle")
	game.player._update_camera_mode()
	_expect(game.gameplay_state.selected_vehicle == starting_vehicle, "Cancelling vehicle choice changed selection")
	_expect(not game.modal_panel.visible and game.player.controls_enabled, "Cancelling did not restore gameplay")
	game._choose_vehicle(1)
	_expect(game.current_vehicle.display_name == "Cargo Comet", "Vehicle selection did not bind the runtime vehicle")
	game._handle_vehicle_access()
	_expect(game.current_vehicle.door_open and not game.driving, "First vehicle-door interaction did not open the door")
	game._handle_vehicle_access()
	_expect(game.driving and not game.player.visible and game.current_vehicle.driving_active, "Second door interaction did not enter the vehicle")
	game._attempt_vehicle_exit()
	_expect(not game.driving and game.player.visible and game.current_vehicle.door_open, "Parked vehicle exit did not restore the courier")
	game._handle_vehicle_access()
	_expect(not game.current_vehicle.door_open, "Post-exit door interaction did not close the door")
	game.gameplay_state = load("res://src/gameplay_state.gd").new()
	game._open_encounter_menu()
	_expect(game.active_modal == "encounter" and "De-escalate" in game.modal_label.text, "Encounter choices did not open")
	game._close_modal("Contract close")
	for boundary_name in ["WorldBoundaryNorth", "WorldBoundarySouth", "WorldBoundaryWest", "WorldBoundaryEast"]:
		_expect(game.get_node_or_null(boundary_name) is StaticBody3D, "World boundary is missing: %s" % boundary_name)
	for environment_name in ["RouteRoad", "SidewalkNorth", "Home", "HomeDoor", "Warehouse", "WarehouseDoor", "ParkedVehicle", "CargoComet", "RivalCourierBody", "Hydrant"]:
		_expect(game.get_node_or_null(environment_name) != null, "3D environment feature is missing: %s" % environment_name)

	if failures.is_empty():
		print("MAIN_CONTRACT_PASS pause=true contextual_anchors=8 drivers=4 route_scan_delivery=true vehicle_cancel=true camera_leak_blocked=true encounter_gated=true world_boundaries=4 environment_features=10")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("MAIN_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
