extends SceneTree

const GameplayState = preload("res://src/gameplay_state.gd")
const TEST_SAVE := "user://package_peddler_runtime_persistence_contract.json"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _new_game() -> Node:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	game.runtime_save_path = TEST_SAVE
	root.add_child(game)
	await process_frame
	return game

func _loaded_route_state() -> PackagePeddlerGameplayState:
	var state := GameplayState.new()
	state.select_vehicle(1)
	state.select_driver(2)
	state.accept_route()
	for definition in GameplayState.STOP_DEFINITIONS:
		state.scan_package(String(definition.tracking_id))
	state.load_package()
	state.depart_route()
	return state

func _complete_route(state: PackagePeddlerGameplayState) -> void:
	while state.route_phase != "ROUTE_COMPLETE":
		state.arrive_at_stop()
		var stop: Dictionary = state.stops[state.current_stop_id]
		if String(stop.archetype) == "UNSAFE_ANIMAL":
			state.resolve_stop_complication("contact_customer")
		state.retrieve_package()
		state.place_package(String(stop.placement_rule))
		state.confirm_delivery(String(stop.confirmation))

func _run() -> void:
	_cleanup()

	# Save while fully seated. The runtime snapshot must capture the current
	# vehicle transform, transmission, closed door and canonical seated state.
	var first := await _new_game()
	first.gameplay_state = _loaded_route_state()
	first._select_runtime_vehicle(1)
	first.current_vehicle.global_position = Vector3(18.5, 0.05, 7.25)
	first.current_vehicle.rotation.y = 0.73
	first.current_vehicle.parked = false
	first.current_vehicle.set_door_open(false)
	first._settle_inside_vehicle()
	_expect(first._save_game(), "Seated runtime save failed")
	first.queue_free()
	await process_frame

	var seated_reload := await _new_game()
	_expect(seated_reload.gameplay_state.route_phase == "DRIVING", "Scene reopen lost route progress")
	_expect(seated_reload.driving and not seated_reload.player.visible and seated_reload.current_vehicle.driving_active, "Scene reopen did not restore one canonical seated courier")
	var restored_horizontal := Vector2(seated_reload.current_vehicle.global_position.x, seated_reload.current_vehicle.global_position.z)
	_expect(restored_horizontal.distance_to(Vector2(18.5, 7.25)) < 0.02, "Scene reopen restored a stale vehicle position: %s" % seated_reload.current_vehicle.global_position)
	_expect(is_equal_approx(seated_reload.current_vehicle.rotation.y, 0.73), "Scene reopen lost vehicle rotation")
	_expect(not seated_reload.current_vehicle.parked and not seated_reload.current_vehicle.door_open, "Scene reopen lost transmission/door state")

	# Exit, save, close, and reopen. Player and vehicle must remain co-located,
	# with the post-exit door prompt restored rather than spawning at the depot.
	seated_reload.current_vehicle.parked = true
	seated_reload._settle_outside_vehicle(true)
	var expected_player_position: Vector3 = seated_reload.player.global_position
	seated_reload.queue_free()
	await process_frame
	var outside_reload := await _new_game()
	_expect(not outside_reload.driving and outside_reload.player.visible, "On-foot reload incorrectly resumed driving")
	_expect(outside_reload.player.global_position.distance_to(expected_player_position) < 0.02, "On-foot reload stranded the player at the depot")
	_expect(outside_reload.player.global_position.distance_to(outside_reload.current_vehicle.exit_position()) < 0.1, "Player and vehicle were not co-located after reload")
	_expect(outside_reload.current_vehicle.door_open and outside_reload.door_waiting_for_close, "Post-exit door state was not restored")
	_expect(String(outside_reload.vehicle_door_point.get_meta("interaction_text", "")).contains("close"), "Post-exit door prompt was not restored")

	# A completed payout must survive a real scene close/reopen and remain
	# idempotent. Saving failures must also be visible to the player.
	_complete_route(outside_reload.gameplay_state)
	_expect(outside_reload.gameplay_state.credits == 440, "Pre-save route payout is wrong")
	_expect(outside_reload._save_game(), "Completed-route runtime save failed")
	outside_reload.queue_free()
	await process_frame
	var completed_reload := await _new_game()
	_expect(completed_reload.gameplay_state.route_phase == "ROUTE_COMPLETE" and completed_reload.gameplay_state.credits == 440, "Completed payout did not survive scene reopen")
	var duplicate: Dictionary = completed_reload.gameplay_state.confirm_delivery("PHOTO")
	_expect(not duplicate.accepted and duplicate.reward == 0 and completed_reload.gameplay_state.credits == 440, "Scene reopen allowed a duplicate payout")
	completed_reload.runtime_save_path = "user://missing/runtime/save.json"
	_expect(not completed_reload._save_game() and completed_reload.save_warning != "", "Save failure was not detected and surfaced")
	_expect("SAVE WARNING" in completed_reload.status_label.text, "Save failure warning was not kept in the HUD")
	completed_reload.queue_free()
	await process_frame

	# Interrupted replacement recovery: prefer the last valid backup when the
	# primary is corrupt, then promote the recovered state back to primary.
	var recovery_source := _loaded_route_state()
	recovery_source.credits = 0
	_expect(recovery_source.save_game(TEST_SAVE), "Recovery fixture save failed")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(TEST_SAVE), ProjectSettings.globalize_path(TEST_SAVE + ".bak"))
	var corrupt := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	corrupt.store_string("{ interrupted")
	corrupt.close()
	var recovered := GameplayState.new()
	_expect(recovered.load_game(TEST_SAVE) and recovered.route_phase == "DRIVING", "Valid backup was not recovered after interrupted replacement")
	_expect(FileAccess.file_exists(TEST_SAVE), "Recovered backup was not promoted to primary")

	_cleanup()
	if failures.is_empty():
		print("RUNTIME_PERSISTENCE_INTEGRATION_CONTRACT_PASS seated_reload=true transform=true parked_door=true co_location=true payout_once=true save_failure=true backup_recovery=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("RUNTIME_PERSISTENCE_INTEGRATION_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
