extends SceneTree

const GameplayState = preload("res://src/gameplay_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.runtime_save_path = "user://package_peddler_five_stop_scene_contract.json"
	game._close_modal("Scene contract")

	for stop_id in ["WB-01", "WB-02", "WB-03", "WB-04", "WB-05"]:
		_expect(game.stop_arrivals.has(stop_id) and game.stop_delivery_points.has(stop_id) and game.stop_proof_points.has(stop_id), "Three-marker flow missing for %s" % stop_id)
		var arrival := game.stop_arrivals[stop_id] as Marker3D
		_expect(absf(arrival.global_position.x) < 33.5 and absf(arrival.global_position.z) < 33.5, "Arrival outside world bounds: %s" % stop_id)
		_expect(arrival.global_position.y >= 0.5, "Arrival is below road grade: %s" % stop_id)
		var parking_shape := BoxShape3D.new()
		parking_shape.size = Vector3(2.15, 1.45, 4.6)
		var parking_query := PhysicsShapeQueryParameters3D.new()
		parking_query.shape = parking_shape
		parking_query.transform = Transform3D(Basis.IDENTITY, Vector3(arrival.global_position.x, 0.87, arrival.global_position.z))
		parking_query.collision_mask = 1
		var obstructions: Array[Dictionary] = game.get_world_3d().direct_space_state.intersect_shape(parking_query, 8)
		var obstruction_names: Array[String] = []
		for obstruction in obstructions:
			var collider = obstruction.get("collider")
			obstruction_names.append(String(collider.name) if collider is Node else "unknown")
		_expect(obstructions.is_empty(), "Vehicle-sized parking area is obstructed: %s by %s" % [stop_id, obstruction_names])

	# Current controller must be able to climb the apartment approach ramp.
	game.player.global_position = Vector3(22.1, 1.0, 3.4)
	game.player.camera_yaw = 0.0
	game.player._apply_camera_rotation()
	Input.action_press("move_right")
	for frame in range(50):
		await physics_frame
	Input.action_release("move_right")
	_expect(game.player.global_position.x > 24.0 and game.player.global_position.y > 0.6, "Apartment stair ramp was not walkable by CharacterBody controller: %s" % game.player.global_position)

	# Restaurant lobby/counter is reachable through its public entrance gap.
	game.player.global_position = Vector3(23.0, 1.0, 15.0)
	game.player.velocity = Vector3.ZERO
	Input.action_press("move_right")
	for frame in range(70):
		await physics_frame
	Input.action_release("move_right")
	_expect(game.player.global_position.x > 26.0, "Restaurant public lobby/counter is blocked by collision: %s" % game.player.global_position)

	# Reload-visible state: carried package and placed package/HUD restore distinctly.
	var state := GameplayState.new()
	state.accept_route()
	for definition in GameplayState.STOP_DEFINITIONS:
		state.scan_package(String(definition.tracking_id))
	state.load_package()
	state.depart_route()
	state.arrive_at_stop(state.current_stop_id)
	state.retrieve_package(String(state.stops[state.current_stop_id].tracking_id))
	var retrieved := GameplayState.new()
	_expect(retrieved.apply_dictionary(state.to_dictionary()), "PACKAGE_RETRIEVED state did not reload")
	game.gameplay_state = retrieved
	game._restore_visible_runtime_state()
	_expect(game.carried_package.visible and not game.placed_package.visible and "PACKAGE_RETRIEVED" in game.route_hud.text, "Retrieved package/HUD did not restore visibly")
	state.place_package(String(state.stops[state.current_stop_id].placement_rule))
	var placed := GameplayState.new()
	_expect(placed.apply_dictionary(state.to_dictionary()), "PLACED state did not reload")
	game.gameplay_state = placed
	game._restore_visible_runtime_state()
	_expect(not game.carried_package.visible and game.placed_package.visible and "PLACED" in game.route_hud.text, "Placed package/HUD did not restore visibly")

	# Restaurant uses a player-facing signature prompt and identity-bound proof marker.
	var restaurant := GameplayState.new()
	restaurant.accept_route()
	restaurant.reorder_stops(["WB-03", "WB-01", "WB-02", "WB-04", "WB-05"])
	for definition in GameplayState.STOP_DEFINITIONS:
		restaurant.scan_package(String(definition.tracking_id))
	restaurant.load_package()
	restaurant.depart_route()
	restaurant.arrive_at_stop("WB-03")
	restaurant.retrieve_package(String(restaurant.stops["WB-03"].tracking_id))
	game.gameplay_state = restaurant
	game._handle_stop_delivery(game.stop_delivery_points["WB-03"])
	_expect(restaurant.route_phase == "PLACED" and "staff signature" in game.status_label.text, "Restaurant placement did not prompt for signature")
	game._handle_stop_proof(game.stop_proof_points["WB-03"])
	_expect(restaurant.route_phase == "DRIVING", "Restaurant signature proof did not advance GPS")

	# Unsafe-animal choice creates a visible warehouse-return obligation and no stop payout.
	var animal := GameplayState.new()
	animal.accept_route()
	animal.reorder_stops(["WB-05", "WB-01", "WB-02", "WB-03", "WB-04"])
	for definition in GameplayState.STOP_DEFINITIONS:
		animal.scan_package(String(definition.tracking_id))
	animal.load_package()
	animal.depart_route()
	animal.arrive_at_stop("WB-05")
	game.gameplay_state = animal
	game._finish_animal_choice("undeliverable")
	_expect(animal.route_phase == "RETURN_PENDING" and "warehouse" in game.status_label.text.to_lower(), "Undeliverable UI did not create warehouse return")
	game._handle_package_station()
	_expect(animal.route_phase == "DRIVING" and animal.credits == 0 and animal.gps_target_id == "WB-01", "Warehouse return UI did not advance without stop payout")

	if failures.is_empty():
		print("FIVE_STOP_SCENE_CONTRACT_PASS anchors=15 bounds=true parking_clear=5 apartment_ramp=true restaurant_access=true signature_ui=true animal_return_ui=true reload_retrieved=true reload_placed=true")
		for suffix in ["", ".tmp", ".bak"]:
			var path: String = game.runtime_save_path + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
