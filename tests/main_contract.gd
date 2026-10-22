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
	# Contracts must not depend on the player's last interactive save.
	# Restore a deterministic on-foot baseline before testing the door flow.
	game.gameplay_state.reset_defaults()
	for vehicle in game.vehicles:
		vehicle.parked = true
		vehicle.speed = 0.0
		vehicle.set_door_open(false)
		vehicle.set_driving_active(false)
	game._select_runtime_vehicle(0)
	game.current_vehicle.parked = true
	game.current_vehicle.set_door_open(false)
	game.current_vehicle.set_driving_active(false)
	game.driving = false
	game.player.set_player_active(true)
	game.vehicle_door_point.add_to_group("interactable")
	game.runtime_save_path = "user://package_peddler_main_contract.json"
	for suffix in ["", ".tmp", ".bak"]:
		var test_path: String = game.runtime_save_path + suffix
		if FileAccess.file_exists(test_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))

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
	_expect(vehicle_point is Marker3D and vehicle_point.is_in_group("interactable"), "Vehicle interaction anchor is missing")
	_expect(vehicle_selector is Marker3D and vehicle_selector.is_in_group("interactable"), "Vehicle selector anchor is missing")
	_expect(driver_kiosk is Marker3D and driver_kiosk.is_in_group("interactable"), "Driver selector anchor is missing")
	_expect(warehouse_point is Marker3D and warehouse_point.is_in_group("interactable"), "Warehouse interaction anchor is missing")
	_expect(contested_point is Marker3D and contested_point.is_in_group("interactable"), "Contested-address anchor is missing")
	_expect(package_station is Marker3D and package_station.is_in_group("interactable"), "Package station anchor is missing")
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
	var unique_stop_ids: Array[String] = []
	for stop_id in ["WB-01", "WB-02", "WB-03", "WB-04", "WB-05"]:
		var suffix: String = stop_id.replace("-", "")
		var arrival := game.get_node_or_null("Stop%sArrival" % suffix)
		var delivery := game.get_node_or_null("Stop%sDelivery" % suffix)
		var proof := game.get_node_or_null("Stop%sProof" % suffix)
		_expect(arrival is Marker3D and arrival.get_meta("interaction_kind") == "stop_arrival", "Arrival anchor missing for %s" % stop_id)
		_expect(delivery is Marker3D and delivery.get_meta("interaction_kind") == "stop_delivery", "Delivery anchor missing for %s" % stop_id)
		_expect(proof is Marker3D and proof.get_meta("interaction_kind") == "stop_proof", "Proof anchor missing for %s" % stop_id)
		_expect(String(arrival.get_meta("stop_id")) == stop_id and String(delivery.get_meta("stop_id")) == stop_id and String(proof.get_meta("stop_id")) == stop_id, "Stop identity mismatch for %s" % stop_id)
		unique_stop_ids.append(String(arrival.get_meta("stop_id")))
	_expect(unique_stop_ids.duplicate().size() == 5, "Five unique stop identities were not created")
	game.gameplay_state = load("res://src/gameplay_state.gd").new()
	game._open_route_menu()
	_expect("Accept displayed order" in game.modal_label.text and "manual reorder" in game.modal_label.text, "Player-facing route planner choices are missing")
	game.route_draft_order.assign(game.MANUAL_STOP_ORDER)
	game._accept_planned_route(game.route_draft_order)
	_expect(game.gameplay_state.route_order == game.MANUAL_STOP_ORDER and game.route_hud.text.contains("GPS:"), "Manual route choice or GPS HUD did not apply")
	for interaction in range(6):
		game._handle_package_station()
	_expect(game.gameplay_state.route_phase == "LOADED", "Five-package scan/load UI did not reach LOADED")
	var wrong_arrival := game.get_node("StopWB01Arrival") as Marker3D
	game.gameplay_state.depart_route()
	game._handle_stop_arrival(wrong_arrival)
	_expect(game.gameplay_state.route_phase == "DRIVING", "Wrong stop interaction advanced route state")
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
	game._open_animal_menu()
	_expect("Wait for customer" in game.modal_label.text and "Contact customer" in game.modal_label.text and "Mark undeliverable" in game.modal_label.text, "Animal safety/return UI choices are missing")
	game._close_modal("Animal UI contract")
	game._open_encounter_menu()
	_expect(game.active_modal == "encounter" and "De-escalate" in game.modal_label.text, "Encounter choices did not open")
	game._close_modal("Contract close")
	for boundary_name in ["WorldBoundaryNorth", "WorldBoundarySouth", "WorldBoundaryWest", "WorldBoundaryEast"]:
		_expect(game.get_node_or_null(boundary_name) is StaticBody3D, "World boundary is missing: %s" % boundary_name)
	for environment_name in ["RouteRoad", "RouteRoadEast", "RouteRoadSouth", "Home", "ApartmentBuilding", "ApartmentDoorC204", "Restaurant", "RestaurantCounter", "OverlookHome", "DeliveryDolly", "AnimalYardHome", "YardDogBody", "Warehouse", "ParkedVehicle", "CargoComet"]:
		_expect(game.get_node_or_null(environment_name) != null, "3D environment feature is missing: %s" % environment_name)

	if failures.is_empty():
		if FileAccess.file_exists(game.runtime_save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(game.runtime_save_path))
		print("MAIN_CONTRACT_PASS pause=true stop_anchors=15 unique_stops=5 planner_ui=true gps_hud=true scan_load_ui=true wrong_stop_guard=true drivers=4 vehicles=2 environment_features=15")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("MAIN_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
