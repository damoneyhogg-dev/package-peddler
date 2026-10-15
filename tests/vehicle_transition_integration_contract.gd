extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _advance_transition(game: Node, seconds: float) -> void:
	game.player._update_authored_presentation(seconds)

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.runtime_save_path = "user://package_peddler_vehicle_transition_contract.json"
	for suffix in ["", ".tmp", ".bak"]:
		var test_path: String = game.runtime_save_path + suffix
		if FileAccess.file_exists(test_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	game.force_vehicle_transition_visuals = true
	game._choose_driver(2)
	if FileAccess.file_exists(game.runtime_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.runtime_save_path))
	var vehicle = game.current_vehicle

	# Entry starts with only the walking courier visible. Nothing may drive,
	# switch camera, show the seated duplicate, or save before presentation end.
	vehicle.set_door_open(true)
	game._enter_vehicle()
	_expect(game.vehicle_transition_active and game.vehicle_transition_kind == "vehicle_enter", "Entry transition did not become the integration gate")
	_expect(not game.driving and not vehicle.driving_active, "Driving activated before full-body entry completed")
	_expect(game.player.visible and not vehicle.seated_driver.visible, "Entry displayed a duplicate or hid the walking courier too early")
	_expect(game.player.camera.current and not vehicle.vehicle_camera.current, "Vehicle camera activated before entry completed")
	_expect(not game._save_game() and not FileAccess.file_exists(game.runtime_save_path), "Save was allowed during entry transition")
	var parked_before: bool = vehicle.parked
	var park_event := InputEventAction.new()
	park_event.action = "vehicle_park"
	park_event.pressed = true
	game._unhandled_input(park_event)
	_expect(vehicle.parked == parked_before, "Park input leaked through entry transition")
	_advance_transition(game, 0.72)
	_expect(game.vehicle_transition_active and game.player.visible and not vehicle.seated_driver.visible, "Entry activated the seated driver at mid-transition")
	_advance_transition(game, 0.72)
	_expect(not game.vehicle_transition_active and game.driving and vehicle.driving_active, "Driving did not activate after entry presentation finished")
	_expect(not game.player.visible and vehicle.seated_driver.visible, "Completed entry did not leave exactly the seated courier visible")
	_expect(vehicle.vehicle_camera.current and not game.player.camera.current, "Completed entry did not switch to vehicle camera")
	_expect(vehicle.driver_variant == 2 and int(vehicle.seated_driver.get_meta("driver_variant", -1)) == 2, "Selected driver appearance did not reach seated avatar")

	# Exit begins by hiding the seated representation, then completes outside.
	game._attempt_vehicle_exit()
	_expect(game.vehicle_transition_active and game.vehicle_transition_kind == "vehicle_exit", "Exit transition did not become the integration gate")
	_expect(game.driving and not vehicle.driving_active, "Vehicle input remained active during exit")
	_expect(game.player.visible and not vehicle.seated_driver.visible, "Exit showed duplicate couriers")
	_expect(not vehicle.vehicle_camera.current and game.player.camera.current, "Exit camera did not remain with full-body presentation")
	_advance_transition(game, 1.40)
	_expect(not game.vehicle_transition_active and not game.driving and game.player.visible and not vehicle.seated_driver.visible, "Exit did not settle canonically on foot")
	_expect(game.vehicle_door_point.is_in_group("interactable"), "Exit did not restore the vehicle-door interaction")

	# Cancelling entry resolves outside; cancelling exit resolves fully seated.
	game.door_waiting_for_close = false
	vehicle.set_door_open(true)
	game._enter_vehicle()
	game._resolve_vehicle_transition_for_interruption()
	_expect(not game.vehicle_transition_active and not game.driving and game.player.visible and not vehicle.seated_driver.visible, "Interrupted entry did not settle outside")
	game._enter_vehicle()
	_advance_transition(game, 1.40)
	game._attempt_vehicle_exit()
	game._resolve_vehicle_transition_for_interruption()
	_expect(not game.vehicle_transition_active and game.driving and vehicle.driving_active, "Interrupted exit did not settle fully seated")
	_expect(not game.player.visible and vehicle.seated_driver.visible and vehicle.vehicle_camera.current, "Interrupted exit left duplicate/incorrect cameras")

	# Pause follows the same deterministic interruption policy and repeated cycles
	# must not leave extra input/camera/visibility state behind.
	game._attempt_vehicle_exit()
	_advance_transition(game, 1.40)
	vehicle.set_door_open(true)
	game.door_waiting_for_close = false
	game._enter_vehicle()
	game._toggle_pause()
	_expect(paused and not game.vehicle_transition_active and not game.driving and game.player.visible, "Pause during entry did not resolve outside before pausing")
	game._toggle_pause()
	_expect(not paused, "Pause contract did not resume")
	game._enter_vehicle()
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(not game.vehicle_transition_active and not game.driving and game.player.visible and not vehicle.seated_driver.visible, "Focus loss during entry did not resolve outside")
	game._enter_vehicle()
	_advance_transition(game, 1.40)
	_expect(game.driving and not game.player.visible and vehicle.seated_driver.visible, "Repeated entry cycle left inconsistent visibility")

	for suffix in ["", ".tmp", ".bak"]:
		var cleanup_path: String = game.runtime_save_path + suffix
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))

	if failures.is_empty():
		print("VEHICLE_TRANSITION_INTEGRATION_CONTRACT_PASS delayed_activation=true input_gate=true save_gate=true single_courier=true camera_sequence=true driver_variant=true cancel=true pause=true focus_loss=true repeated_cycles=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("VEHICLE_TRANSITION_INTEGRATION_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
