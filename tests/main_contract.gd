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
	var warehouse_point := game.get_node_or_null("WarehouseEntrance")
	var contested_point := game.get_node_or_null("ContestedAddress")
	_expect(vehicle_point is Marker3D and vehicle_point.is_in_group("interactable"), "Vehicle interaction anchor is missing")
	_expect(warehouse_point is Marker3D and warehouse_point.is_in_group("interactable"), "Warehouse interaction anchor is missing")
	_expect(contested_point is Marker3D and contested_point.is_in_group("interactable"), "Contested-address anchor is missing")
	_expect(vehicle_point.get_meta("interaction_kind") == "vehicle_swap", "Vehicle anchor is not wired to swap choice")
	_expect(contested_point.get_meta("interaction_kind") == "contested_address", "Address anchor is not flagged for its encounter")
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
	game.gameplay_state = load("res://src/gameplay_state.gd").new()
	game._open_encounter_menu()
	_expect(game.active_modal == "encounter" and "De-escalate" in game.modal_label.text, "Encounter choices did not open")
	game._close_modal("Contract close")
	for boundary_name in ["WorldBoundaryNorth", "WorldBoundarySouth", "WorldBoundaryWest", "WorldBoundaryEast"]:
		_expect(game.get_node_or_null(boundary_name) is StaticBody3D, "World boundary is missing: %s" % boundary_name)
	for environment_name in ["RouteRoad", "SidewalkNorth", "Home", "HomeDoor", "Warehouse", "WarehouseDoor", "ParkedVehicle", "CargoComet", "RivalCourierBody", "Hydrant"]:
		_expect(game.get_node_or_null(environment_name) != null, "3D environment feature is missing: %s" % environment_name)

	if failures.is_empty():
		print("MAIN_CONTRACT_PASS pause=true contextual_anchors=3 vehicle_cancel=true camera_leak_blocked=true encounter_choices=true world_boundaries=4 environment_features=10")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("MAIN_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
