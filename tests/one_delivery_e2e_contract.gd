extends SceneTree

const GameplayState = preload("res://src/gameplay_state.gd")
const TEST_SAVE := "user://package_peddler_five_delivery_e2e.json"
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
	for definition in GameplayState.STOP_DEFINITIONS:
		_expect(state.scan_package(String(definition.tracking_id)).accepted, "Package scan failed")
	_expect(state.load_package().accepted and state.depart_route().accepted, "Load/depart failed")
	for index in range(5):
		var stop_id := state.current_stop_id
		var tracking_id := String(state.stops[stop_id].tracking_id)
		_expect(state.arrive_at_stop(stop_id).accepted, "Stop %d arrival failed" % index)
		if String(state.stops[stop_id].archetype) == "UNSAFE_ANIMAL":
			_expect(state.resolve_stop_complication("wait").accepted, "Safe animal wait path failed")
		_expect(state.retrieve_package(tracking_id).accepted, "Stop %d retrieval failed" % index)
		var rule := String(state.stops[stop_id].placement_rule)
		_expect(not state.place_package("WRONG_PLACEMENT").accepted, "Invalid placement passed at stop %d" % index)
		_expect(state.place_package(rule).accepted, "Stop %d placement failed" % index)
		var proof := String(state.stops[stop_id].confirmation)
		var result := state.confirm_delivery(proof)
		_expect(result.accepted, "Stop %d confirmation failed" % index)
		if index == 2:
			_expect(state.save_game(TEST_SAVE), "Mid-route save failed")
			var resumed := GameplayState.new()
			_expect(resumed.load_game(TEST_SAVE), "Mid-route reload failed")
			state = resumed
	_expect(state.route_phase == "ROUTE_COMPLETE", "Five stops did not complete route")
	_expect(state.gross_earnings == 475 and state.net_earnings == 440 and state.credits == 440, "Earnings summary is wrong")
	_expect(state.save_game(TEST_SAVE), "Completed route save failed")
	var loaded := GameplayState.new()
	_expect(loaded.load_game(TEST_SAVE), "Completed route reload failed")
	_expect(loaded.route_phase == "ROUTE_COMPLETE" and loaded.credits == 440, "Completion did not persist")
	var duplicate := loaded.confirm_delivery()
	_expect(not duplicate.accepted and duplicate.reward == 0 and loaded.credits == 440, "Reload allowed duplicate payout")
	_cleanup()
	if failures.is_empty():
		print("FIVE_DELIVERY_E2E_CONTRACT_PASS stops=5 save_mid_route=true reload=true gross=475 expenses=35 net=440 payout_once=true")
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
